
CHIP_MEMORY_ADDRESS = $000000
INITIAL_COPPER_ADDRESS = $000000

TEXT_BUFFER_SIZE = 3000

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

	; Print demo text
	bsr	PrintDemoText

	; Get chip memory size
	move.l	$4.w,a6
	move.l	MaxLocMem(a6),ChipMemorySize

	; Detect only-chip config
	moveq.l	#0,d0
	cmp.l	#Main,ChipMemorySize
	sgt.b	d0
	neg.b	d0
	move.l	d0,OnlyChip

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
	move.l	OnlyChip(pc),d1
	beq.b	.full
	sub.l	#BOOTSTRAP_SIZE,d0
.full:	move.l	d0,ChipBufferSize
	jsr	_LVOAllocAbs(a6)
	move.l	d0,ChipBuffer
	jsr	_LVOPermit(a6)

	; Check that chip buffer is at least as big as low memory
	move.l	ChipBufferSize(pc),d0
	cmp.l	ChipBuffer(pc),d0
	blt.b	Exit

	; Allocate extra buffer for saving used chip memory
	move.l	OnlyChip(pc),d1
	bne.b	.skip
	move.l	ChipMemorySize(pc),d0
	sub.l	ChipBufferSize(pc),d0
	move.l	d0,ExtraBufferSize
	moveq.l	#0,d1
	jsr	_LVOAllocMem(a6)
	move.l	d0,ExtraBuffer
	beq.b	Exit
.skip:
	; Load memory image
	bsr	LoadChipDataFile
	move.l	ReturnCode(pc),d0
	bne.b	Exit

	lea	$dff000,a3

	bsr	CloseSystem

	; If only chip, copy and run bootstrap code
	move.l	OnlyChip(pc),d1
	bne.b	OnlyChipMain

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


OnlyChipMain:
	; Do Not Disturb
	move.w	#$4000,intena(a3)

	; Copy bootstrap code
	lea	Bootstrap_End(pc),a0
	move.l	ChipMemorySize(pc),a1
	lea	BootstrapSupervisorCore-Bootstrap_End(a1),a5
	moveq.l	#BOOTSTRAP_SIZE/4-1,d1
.copy:	move.l	-(a0),-(a1)
	dbf	d1,.copy

	; Run bootstrap code
	move.l	$4.w,a6
	cmp.w	#37,LIB_VERSION(a6)
	blt.b	.noflush
	jsr	_LVOCacheClearU(a6)
.noflush:
	jsr	_LVOSupervisor(a6)
	; No return to here


PrintDemoText:
	move.l	DosBase(pc),a6

	; Get output
	jsr	_LVOOutput(a6)
	move.l	d0,d5
	beq.b	.no_text

	; Open file
	move.l	#DemoTextFileName,d1
	move.l	#MODE_OLDFILE,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	beq.b	.no_text

	; Allocate buffer on stack
	lea	-TEXT_BUFFER_SIZE(a7),a7
.print:
	; Read text
	move.l	d4,d1
	move.l	a7,d2
	move.l	#TEXT_BUFFER_SIZE,d3
	jsr	_LVORead(a6)
	move.l	d0,d3
	ble.b	.done

	; Print text
	move.l	d5,d1
	move.l	a7,d2
	jsr	_LVOWrite(a6)

	cmp.l	#TEXT_BUFFER_SIZE,d3
	beq.b	.print
.done:
	; Deallocate buffer
	lea	TEXT_BUFFER_SIZE(a7),a7

	; Close file
	move.l	d4,d1
	jsr	_LVOClose(a6)
.no_text:
	rts


LoadChipDataFile:
	move.l	DosBase(pc),a6

	; Open chip ram data file
	moveq.l	#0,d5
	move.l	#ChipDataFileName,d1
	move.l	#MODE_OLDFILE,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	bne.b	.open_ok

	; Try compressed
	moveq.l	#1,d5
	move.l	#CompressedChipDataFileName,d1
	move.l	#MODE_OLDFILE,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	bne.b	.open_ok

	; Open failed - set return code
	jsr	_LVOIoErr(a6)
	move.l	d0,ReturnCode
	rts
.open_ok:
	move.l	d5,Compressed

	; Read low memory contents
	move.l	d4,d1
	move.l	ChipBufferSize(pc),d2
	move.l	ChipBuffer(pc),d3
	jsr	_LVORead(a6)
	move.l	d0,ChipDataSize

	; Read mid memory contents
	move.l	d4,d1
	move.l	ChipBuffer(pc),d2
	move.l	ChipBufferSize(pc),d3
	sub.l	ChipBuffer(pc),d3
	jsr	_LVORead(a6)
	add.l	d0,ChipDataSize

	; Stop here if only chip
	move.l	OnlyChip(pc),d1
	beq.b	.extra
	cmp.l	d3,d0
	blt.b	.close
	move.l	#ERROR_NO_FREE_STORE,ReturnCode
	bra.b	.close
.extra:
	; Read high memory contents
	move.l	d4,d1
	move.l	ExtraBuffer(pc),d2
	move.l	ExtraBufferSize(pc),d3
	jsr	_LVORead(a6)
	add.l	d0,ChipDataSize
.close:
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

	move.l	ChipMemorySize(pc),a0
	bsr	Decompress

	move.l	ChipDataSize(pc),a1
	move.l	ChipMemorySize(pc),d1
	sub.l	a1,d1
	bsr	BlitClear
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


Bootstrap_Begin:

BootstrapSupervisorCore:
	; Set interrupt level to 7 to prevent the demo from hijacking the CPU.
	or.w	#$0700,sr

	; Switch stack
	lea	Stack(pc),a7

	jsr	SetInitialState

	; Copy low memory data
	move.l	ChipBufferSize(pc),a0
	move.l	#CHIP_MEMORY_ADDRESS,a1
	move.l	ChipBuffer(pc),d1
	bsr	BlitCopy

	; Decompress if compressed
	move.l	ChipMemorySize(pc),a0
	lea	-BOOTSTRAP_SIZE(a0),a0
	bsr	Decompress

	; Clear until bootstrap code
	move.l	ChipDataSize(pc),a1
	move.l	ChipMemorySize(pc),d1
	sub.l	#BOOTSTRAP_SIZE,d1
	sub.l	a1,d1
	bsr	BlitClear

	; Set dummy copper start address and wait for copper to latch it
	lea	DummyCopper(pc),a0
	move.l	a0,cop1lc(a3)
	bsr	WaitVbl

	; Enable DMAs.
	move.w	#$87c0,dmacon(a3)

	; Set copper danger flag
	move.w	#$0002,copcon(a3)

	; Clear bootstrap code
	move.w	#(BOOTSTRAP_SIZE<<(6-3))+4,bltsize(a3)

	; Set initial copper start address
	move.l	#INITIAL_COPPER_ADDRESS,cop1lc(a3)

	; Stop
	stop	#$2700


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


Decompress:
	; A0 = End of space

	move.l	Compressed(pc),d0
	beq.b	.not

	move.l	ChipDataSize(pc),d0
	addq.l	#3,d0
	and.w	#-4,d0
	move.l	d0,a1

.move:	move.l	-(a1),-(a0)
	move.l	a1,d0
	bne.b	.move

	bsr	zx0_decompress

	lea	ChipDataSize(pc),a0
	move.l	a1,(a0)
.not:
	rts

	include	NC:runner/unzx0_68000.S


DummyCopper:
	dc.l	$fffffffe

ChipMemorySize:
	dc.l	0
ChipBuffer:
	dc.l	0
ChipBufferSize:
	dc.l	0
ChipDataSize:
	dc.l	0
Compressed:
	dc.l	0

	ds.l	5
Stack:

Bootstrap_End:

BOOTSTRAP_SIZE	=	(Bootstrap_End-Bootstrap_Begin+7)&-8


DosName:
	dc.b	"dos.library",0
GraphicsName:
	dc.b	"graphics.library",0
DemoTextFileName:
	dc.b	"demo.txt",0
ChipDataFileName:
	dc.b	"chip.dat",0
CompressedChipDataFileName:
	dc.b	"chip.zx0",0
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
OnlyChip:
	dc.l	0
ExtraBuffer:
	dc.l	0
ExtraBufferSize:
	dc.l	0
