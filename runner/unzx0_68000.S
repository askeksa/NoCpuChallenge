; The ZX0 decompressors in this file are based on the 68000 decompressor by
; Emmanuel Marty. The code is modified in two ways:
;
; 1. Save and restore of D2/A2 is removed.
; 2. A version for split decompression across two memory regions is added.


;  unzx0_68000.s - ZX0 decompressor for 68000 - 88 bytes
;
;  in:  a0 = start of compressed data
;       a1 = start of decompression buffer
;
;  Copyright (C) 2021 Emmanuel Marty
;  ZX0 compression (c) 2021 Einar Saukas, https://github.com/einar-saukas/ZX0
;
;  This software is provided 'as-is', without any express or implied
;  warranty.  In no event will the authors be held liable for any damages
;  arising from the use of this software.
;
;  Permission is granted to anyone to use this software for any purpose,
;  including commercial applications, and to alter it and redistribute it
;  freely, subject to the following restrictions:
;
;  1. The origin of this software must not be misrepresented; you must not
;     claim that you wrote the original software. If you use this software
;     in a product, an acknowledgment in the product documentation would be
;     appreciated but is not required.
;  2. Altered source versions must be plainly marked as such, and must not be
;     misrepresented as being the original software.
;  3. This notice may not be removed or altered from any source distribution.

zx0_decompress:
               moveq #-128,d1       ; initialize empty bit queue
                                    ; plus bit to roll into carry
               moveq #-1,d2         ; initialize rep-offset to 1

.literals:     bsr.s .get_elias     ; read number of literals to copy
               subq.l #1,d0         ; dbf will loop until d0 is -1, not 0
.copy_lits:    move.b (a0)+,(a1)+   ; copy literal byte
               dbf d0,.copy_lits    ; loop for all literal bytes

               add.b d1,d1          ; read 'match or rep-match' bit
               bcs.s .get_offset    ; if 1: read offset, if 0: rep-match

.rep_match:    bsr.s .get_elias     ; read match length (starts at 1)
.do_copy:      subq.l #1,d0         ; dbf will loop until d0 is -1, not 0
.do_copy_offs: move.l a1,a2         ; calculate backreference address
               add.l d2,a2          ; (dest + negative match offset)
.copy_match:   move.b (a2)+,(a1)+   ; copy matched byte
               dbf d0,.copy_match   ; loop for all matched bytes

               add.b d1,d1          ; read 'literal or match' bit
               bcc.s .literals      ; if 0: go copy literals

.get_offset:   moveq #-2,d0         ; initialize value to $fe
               bsr.s .elias_loop    ; read high byte of match offset
               addq.b #1,d0         ; obtain negative offset high byte
               beq.s .done          ; exit if EOD marker
               move.w d0,d2         ; transfer negative high byte into d2
               lsl.w #8,d2          ; shift it to make room for low byte

               moveq #1,d0          ; initialize length value to 1
               move.b (a0)+,d2      ; read low byte of offset + 1 bit of len
               asr.l #1,d2          ; shift len bit into carry/offset in place
               bcs.s .do_copy_offs  ; if len bit is set, no need for more
               bsr.s .elias_bt      ; read rest of elias-encoded match length
               bra.s .do_copy_offs  ; go copy match

.get_elias:    moveq #1,d0          ; initialize value to 1
.elias_loop:   add.b d1,d1          ; shift bit queue, high bit into carry
               bne.s .got_bit       ; queue not empty, bits remain
               move.b (a0)+,d1      ; read 8 new bits
               addx.b d1,d1         ; shift bit queue, high bit into carry
                                    ; and shift 1 from carry into bit queue

.got_bit:      bcs.s .got_elias     ; done if control bit is 1
.elias_bt:     add.b d1,d1          ; read data bit
               addx.l d0,d0         ; shift data bit into value in d0
               bra.s .elias_loop    ; keep reading
.done:
.got_elias:    rts


; Second stage of the split-region decompressor, entered when both the source
; and destination pointers have crossed into the second region.
zx0_decompress_split2:
.literals:     bsr.s zx0_decompress\.get_elias
               subq.l #1,d0         ; dbf will loop until d0 is -1, not 0
.copy_lits:    move.b (a0)+,(a1)+   ; copy literal byte
               dbf d0,.copy_lits    ; loop for all literal bytes

               add.b d1,d1          ; read 'match or rep-match' bit
               bcs.s .get_offset    ; if 1: read offset, if 0: rep-match

.rep_match:    bsr.s zx0_decompress\.get_elias
.do_copy:      subq.l #1,d0         ; dbf will loop until d0 is -1, not 0
.do_copy_offs: move.l a1,a2         ; calculate backreference address
               add.l d2,a2          ; (dest + negative match offset)
               cmp.l a5,a2          ; Does the match start before the split?
               bhs.b .copy_match
               sub.l a5,a2
               add.l a4,a2
.copy_match:   cmp.l a4,a2          ; Is the match crossing the split?
               bne.b .same
               move.l a5,a2
.same:         move.b (a2)+,(a1)+   ; copy matched byte
               dbf d0,.copy_match   ; loop for all matched bytes

               add.b d1,d1          ; read 'literal or match' bit
               bcc.s .literals      ; if 0: go copy literals

.get_offset:   moveq #-2,d0         ; initialize value to $fe
               bsr.s zx0_decompress\.elias_loop
               addq.b #1,d0         ; obtain negative offset high byte
               beq.s .done          ; exit if EOD marker
               move.w d0,d2         ; transfer negative high byte into d2
               lsl.w #8,d2          ; shift it to make room for low byte

               moveq #1,d0          ; initialize length value to 1
               move.b (a0)+,d2      ; read low byte of offset + 1 bit of len
               asr.l #1,d2          ; shift len bit into carry/offset in place
               bcs.s .do_copy_offs  ; if len bit is set, no need for more
               bsr.s zx0_decompress\.elias_bt
               bra.s .do_copy_offs  ; go copy match

.done:         sub.l a5,a1
               add.l a4,a1
               rts


; ZX0 decompressor for the scenario where both the compressed and uncompressed
; data are split across two separate memory regions.
;
; A0 = Source (compressed) data.
;      Given in the address space of the first region, but can be beyond the
;      end of the first region (signifying that the data starts at a
;      corresponding offset into the second region).
; A1 = Destination (decompressed) data.
;      Must reside inside the first region.
; A4 = End of the first region.
; A5 = Start of the second region.
zx0_decompress_split:
               moveq #-128,d1       ; initialize empty bit queue
                                    ; plus bit to roll into carry
               moveq #-1,d2         ; initialize rep-offset to 1

               cmp.l a4,a0          ; Compressed data starts in second region?
               blo.b .literals
               sub.l a4,a0
               add.l a5,a0
.literals:     bsr.s .get_elias     ; read number of literals to copy
               subq.l #1,d0         ; dbf will loop until d0 is -1, not 0
.copy_lits:    cmp.l a4,a0          ; End of first region reached for input?
               bne.b .src1
               move.l a5,a0
.src1:         cmp.l a4,a1          ; End of first region reached for output?
               bne.b .dst1
               move.l a5,a1
               bra.b zx0_decompress_split2\.copy_lits
.dst1:         move.b (a0)+,(a1)+   ; copy literal byte
               dbf d0,.copy_lits    ; loop for all literal bytes

               add.b d1,d1          ; read 'match or rep-match' bit
               bcs.s .get_offset    ; if 1: read offset, if 0: rep-match

.rep_match:    bsr.s .get_elias     ; read match length (starts at 1)
.do_copy:      subq.l #1,d0         ; dbf will loop until d0 is -1, not 0
.do_copy_offs: move.l a1,a2         ; calculate backreference address
               add.l d2,a2          ; (dest + negative match offset)
.copy_match:   cmp.l a4,a1          ; End of first region reached for output?
               bne.b .dst2
               move.l a5,a1
               bra.b zx0_decompress_split2\.copy_match
.dst2:         move.b (a2)+,(a1)+   ; copy matched byte
               dbf d0,.copy_match   ; loop for all matched bytes

               add.b d1,d1          ; read 'literal or match' bit
               bcc.s .literals      ; if 0: go copy literals

.get_offset:   moveq #-2,d0         ; initialize value to $fe
               bsr.s .elias_loop    ; read high byte of match offset
               addq.b #1,d0         ; obtain negative offset high byte
               beq.s .done          ; exit if EOD marker
               move.w d0,d2         ; transfer negative high byte into d2
               lsl.w #8,d2          ; shift it to make room for low byte

               moveq #1,d0          ; initialize length value to 1
               cmp.l a4,a0          ; End of first region reached for input?
               bne.b .src2
               move.l a5,a0
.src2:         move.b (a0)+,d2      ; read low byte of offset + 1 bit of len
               asr.l #1,d2          ; shift len bit into carry/offset in place
               bcs.s .do_copy_offs  ; if len bit is set, no need for more
               bsr.s .elias_bt      ; read rest of elias-encoded match length
               bra.s .do_copy_offs  ; go copy match

.get_elias:    moveq #1,d0          ; initialize value to 1
.elias_loop:   add.b d1,d1          ; shift bit queue, high bit into carry
               bne.s .got_bit       ; queue not empty, bits remain
               cmp.l a4,a0          ; End of first region reached for input?
               bne.b .src3
               move.l a5,a0
.src3:         move.b (a0)+,d1      ; read 8 new bits
               addx.b d1,d1         ; shift bit queue, high bit into carry
                                    ; and shift 1 from carry into bit queue

.got_bit:      bcs.s .got_elias     ; done if control bit is 1
.elias_bt:     add.b d1,d1          ; read data bit
               addx.l d0,d0         ; shift data bit into value in d0
               bra.s .elias_loop    ; keep reading
.done:
.got_elias:    rts
