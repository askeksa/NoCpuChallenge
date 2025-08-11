
CHIP_MEMORY_ADDRESS = $000000

INITIAL_COPPER_ADDRESS = $000000

	include dos/dos.i
	include	exec/execbase.i
	include	exec/memory.i
	include	graphics/gfxbase.i
	include	hardware/custom.i
	include lvo/dos_lib.i
	include lvo/exec_lib.i
	include lvo/graphics_lib.i


	section main,code

Main:
	move.l	$4.w,a6

	; Open dos.library
	lea	DosName(pc),a1
	jsr	_LVOOldOpenLibrary(a6)
	move.l	d0,DosBase

	; Open graphics.library
	lea	GraphicsName(pc),a1
	jsr	_LVOOldOpenLibrary(a6)
	move.l	d0,GraphicsBase

	; Get chip memory size
	move.l	MaxLocMem(a6),ChipMemorySize

	; Allocate largest available chip memory chunk
	jsr	_LVOForbid(a6)
	lea	MemList(a6),a0
	moveq.l	#0,d0
.findchip:
	move.l	(a0),a0
	btst.b	#MEMB_CHIP,MH_ATTRIBUTES+1(a0)
	beq.b	.findchip
	lea	MH_FIRST(a0),a0
.findlargest:
	move.l	(a0),a0
	cmp.l	MC_BYTES(a0),d0
	bgt.b	.notlargest
	move.l	a0,a1
	move.l	MC_BYTES(a0),d0
.notlargest:
	tst.l	(a0)
	bne.b	.findlargest
	move.l	d0,ChipBufferSize
	jsr	_LVOAllocAbs(a6)
	move.l	d0,ChipBuffer
	jsr	_LVOPermit(a6)

	; Check that chip buffer is at least as big as low memory
	move.l	ChipBufferSize(pc),d0
	cmp.l	ChipBuffer(pc),d0
	blt.b	Exit

	; Allocate extra buffer for saving used chip memory
	move.l	ChipMemorySize(pc),d0
	sub.l	ChipBufferSize(pc),d0
	move.l	d0,ExtraBufferSize
	moveq.l	#0,d1
	jsr	_LVOAllocMem(a6)
	move.l	d0,ExtraBuffer
	beq.b	Exit

	; Load memory image
	bsr	LoadChipDataFile
	move.l	ReturnCode(pc),d0
	bne.b	Exit

	lea	$dff000,a3

	bsr	CloseSystem

.restart:
	move.l	$4.w,a6

	; Run the core in supervisor mode
	lea	SupervisorCore(pc),a5
	jsr	_LVOSupervisor(a6)

	; Reload and restart on RMB
	move.l	RestartFlag(pc),d0
	beq.b	.norestart

	bsr	LoadChipDataFile
	move.l	ReturnCode(pc),d0
	beq.b	.restart

.norestart:
	bsr	WaitLMBReleased
	bsr	OpenSystem

Exit:
	move.l	$4.w,a6

	; Free extra buffer
	move.l	ExtraBuffer(pc),d0
	beq.b	.nobuffer
	move.l	d0,a1
	move.l	ExtraBufferSize(pc),d0
	jsr	_LVOFreeMem(a6)
.nobuffer:

	; Free chip
	move.l	ChipBuffer(pc),d0
	beq.b	.nochip
	move.l	d0,a1
	move.l	ChipBufferSize(pc),d0
	jsr	_LVOFreeMem(a6)
.nochip:

	; Close graphics.library
	move.l	GraphicsBase(pc),a1
	jsr	_LVOCloseLibrary(a6)

	; Close dos.library
	move.l	DosBase(pc),a1
	jsr	_LVOCloseLibrary(a6)

	; Exit
	move.l	ReturnCode(pc),d0
	rts


LoadChipDataFile:
	move.l	DosBase(pc),a6

	; Open chip ram data file
	move.l	#ChipDataFileName,d1
	move.l	#MODE_OLDFILE,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	bne.b	.open_ok

	; Open failed - set return code
	jsr	_LVOIoErr(a6)
	move.l	d0,ReturnCode
	rts
.open_ok:
	; Read low memory contents
	move.l	d4,d1
	move.l	ChipBufferSize(pc),d2
	move.l	ChipBuffer(pc),d3
	jsr	_LVORead(a6)

	; Read mid memory contents
	move.l	d4,d1
	move.l	ChipBuffer(pc),d2
	move.l	ChipBufferSize(pc),d3
	sub.l	ChipBuffer(pc),d3
	jsr	_LVORead(a6)

	; Read high memory contents
	move.l	d4,d1
	move.l	ExtraBuffer(pc),d2
	move.l	ExtraBufferSize(pc),d3
	jsr	_LVORead(a6)

	; Close file
	move.l	d4,d1
	jsr	_LVOClose(a6)
	rts


CloseSystem:
	move.l	GraphicsBase(pc),a6

	; Reserve blitter
	jsr	_LVOOwnBlitter(a6)
	jsr	_LVOWaitBlit(a6)

	; Reset view
	move.l	gb_ActiView(a6),SystemView
	suba.l	a1,a1
	jsr	_LVOLoadView(a6)
	jsr	_LVOWaitTOF(a6)
	jsr	_LVOWaitTOF(a6)

	; Disable DMA
	move.w	#$01bf,dmacon(a3)
	rts

OpenSystem:
	move.l	GraphicsBase(pc),a6

	; Restore system copperlist
	move.l	gb_copinit(a6),cop1lc(a3)

	; Wait for vblank before enabling DMA to prevent copper from
	; executing (now nonexistent) instructions from where it left off.
	bsr	WaitVbl

	; Enable DMA
	move.w	#$83e0,dmacon(a3)

	; Restore system view
	move.l	SystemView(pc),a1
	jsr	_LVOLoadView(a6)

	; Release blitter
	jsr	_LVODisownBlitter(a6)
	rts


SupervisorCore:
	; Set interrupt level to 7 to prevent the demo from hijacking the CPU.
	or.w	#$0700,sr

	; Switch stack, in case the supervisor stack is in chip memory.
	move.l	a7,a6
	lea	Stack(pc),a7

	bsr	SetInitialState
	bsr	SwapChipMemoryIn
	bsr	StartDemo
	bsr	WaitForExitSignal
	bsr	WaitVbl
	bsr	StopDemo
	bsr	SetInitialState
	bsr	WaitBlit
	bsr	SwapChipMemoryOut

	; Restore stack and return
	move.l	a6,a7
	rte

SetInitialState:
	; Turn off audio filter and modulations
	bset.b	#1,$bfe001
	move.w	#$000f,adkcon(a3)

	; PAL mode, long frames
	move.w	#$0020,beamcon0(a3)
	move.w	#$8000,vposw(a3)

	; Set OCS defaults
	move.w	#$0200,bplcon0(a3)
	move.w	#$0000,bplcon1(a3)
	move.w	#$0024,bplcon2(a3)
	move.w	#$0c00,bplcon3(a3)
	move.w	#$0011,bplcon4(a3)
	move.w	#$0000,fmode(a3)

	; Black background
	move.w	#$000,color+0*2(a3)
	rts

StartDemo:
	; Set initial copper start address
	move.l	#INITIAL_COPPER_ADDRESS,cop1lc(a3)

	; Set copper danger flag
	move.w	#$0002,copcon(a3)

	; Wait for vblank before enabling DMA to prevent copper from
	; executing (now nonexistent) instructions from where it left off.
	bsr	WaitVbl

	; Enable bitplane, copper and blitter DMA. Set Blitter Nasty to
	; prevent the CPU from interfering with the demo.
	move.w	#$87c0,dmacon(a3)
	rts

StopDemo:
	; Disable all DMA except blitter
	move.w	#$05bf,dmacon(a3)
	move.w	#$8240,dmacon(a3)

	; Restore system default interrupt enable mask
	move.w	#$1fd3,intena(a3)
	move.w	#$e02c,intena(a3)

	; Clear copper danger flag
	move.w	#$0000,copcon(a3)
	rts

SwapChipMemoryIn:
	move.l	ChipBufferSize(pc),a0
	move.l	#CHIP_MEMORY_ADDRESS,a1
	move.l	ChipBuffer(pc),d1
	bsr	BlitSwap

	move.l	ExtraBuffer(pc),a0
	move.l	ChipBufferSize(pc),a1
	move.l	ExtraBufferSize(pc),d1
	bsr	SwapMemory
	rts

SwapChipMemoryOut:
	move.l	ExtraBuffer(pc),a0
	move.l	ChipBufferSize(pc),a1
	move.l	ExtraBufferSize(pc),d1
	bsr	CopyMemory

	move.l	ChipBufferSize(pc),a0
	move.l	#CHIP_MEMORY_ADDRESS,a1
	move.l	ChipBuffer(pc),d1
	bsr	BlitCopy
	rts

CopyMemory:
	; A0 = Source
	; A1 = Dest
	; D1 = Size
	bra.b	.in
.loop:	move.l	(a0)+,(a1)+
.in:	subq.l	#4,d1
	bge.b	.loop
	rts

SwapMemory:
	; A0 = Source
	; A1 = Dest
	; D1 = Size
	bra.b	.in
.loop:	move.l	(a0),d0
	move.l	(a1),(a0)+
	move.l	d0,(a1)+
.in:	subq.l	#4,d1
	bge.b	.loop
	rts


WaitVbl:
.wait1:	btst.b	#0,vposr+1(a3)
	beq.b	.wait1
.wait2:	btst.b	#0,vposr+1(a3)
	bne.b	.wait2
	rts

WaitBlit:
.wait:	btst.b	#14-8,dmaconr(a3)
	bne.b	.wait
	rts

WaitForExitSignal:
	moveq.l	#0,d0
.wait:
	; Exit on LMB
	btst.b	#6,$bfe001
	beq.b	.exit

	; Exit if Blitter Nasty is cleared.
	btst.b	#10-8,dmaconr(a3)
	beq.b	.exit

	; Restart on RMB
	btst.b	#10-8,potinp(a3)
	bne.b	.wait
	moveq.l	#1,d0
.exit:
	move.l	d0,RestartFlag
	rts

WaitLMBReleased:
.wait:	btst.b	#6,$bfe001
	beq.b	.wait
	rts


BlitClear:
	; A1 = Destination
	; D1 = Size in bytes (must be even)
	move.w	#$0100,d0
	bra.b	Blit

BlitCopy:
	; A0 = Source
	; A1 = Destination
	; D1 = Size in bytes (must be even)
	move.w	#$09f0,d0
	bra.b	Blit

BlitSwap:
	; A0 = Source
	; A1 = Destination
	; D1 = Size in bytes (must be even)
	move.w	#$0b5a,d0
	bsr	Blit
	exg.l	a0,a1
	bsr	Blit
	exg.l	a0,a1
Blit:
	; A0 = Source
	; A1 = Destination
	; D1 = Size in bytes (must be even)
	; D0 = BLTCON0
	bsr	WaitBlit
	move.w	d0,bltcon0(a3)
	move.w	#$0000,bltcon1(a3)
	move.l	#$ffffffff,bltafwm(a3)
	move.l	a1,bltcpt(a3)
	move.l	a0,bltapt(a3)
	move.l	a1,bltdpt(a3)
	move.w	#0,bltcmod(a3)
	move.w	#0,bltamod(a3)
	move.w	#0,bltdmod(a3)

	move.l	d1,d2
	asr.l	#1,d2
	bra.b	.bigin
.big:	move.w	#0,bltsize(a3)
	bsr	WaitBlit
.bigin:	sub.l	#$10000,d2
	bge.b	.big
	moveq.l	#-64,d3
	and.w	d2,d3
	beq.b	.no1
	move.w	d3,bltsize(a3)
	bsr	WaitBlit
.no1:	sub.w	d3,d2
	beq.b	.no2
	or.w	#64,d2
	move.w	d2,bltsize(a3)
	bsr	WaitBlit
.no2:	rts


DosName:
	dc.b	"dos.library",0
GraphicsName:
	dc.b	"graphics.library",0
ChipDataFileName:
	dc.b	"chip.dat",0
	even

DosBase:
	dc.l	0
GraphicsBase:
	dc.l	0
SystemView:
	dc.l	0
ReturnCode:
	dc.l	0
RestartFlag:
	dc.l	0
ChipMemorySize:
	dc.l	0
ChipBuffer:
	dc.l	0
ChipBufferSize:
	dc.l	0
ExtraBuffer:
	dc.l	0
ExtraBufferSize:
	dc.l	0

	ds.l	4
Stack:
