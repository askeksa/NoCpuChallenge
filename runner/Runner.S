
CHIP_MEMORY_ADDRESS = $000000
CHIP_MEMORY_SIZE = $200000

INITIAL_COPPER_ADDRESS = $000000

	include dos/dos.i
	include	graphics/gfxbase.i
	include	hardware/custom.i
	include lvo/dos_lib.i
	include lvo/exec_lib.i
	include lvo/graphics_lib.i


	section main,code_f

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

	bsr	LoadChipDataFile
	tst.l	ReturnCode(pc)
	bne.b	.exit

	lea	$dff000,a3

	bsr	CloseSystem

.restart:
	move.l	$4.w,a6

	; Run the core in supervisor mode
	lea	SupervisorCore(pc),a5
	jsr	_LVOSupervisor(a6)

	; Reload and restart on RMB
	tst.l	RestartFlag(pc)
	beq.b	.norestart

	bsr	LoadChipDataFile
	tst.l	ReturnCode(pc)
	beq.b	.restart

.norestart:
	bsr	WaitLMBReleased
	bsr	OpenSystem

.exit:
	move.l	$4.w,a6

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
	; Read file contents
	move.l	d4,d1
	move.l	#ChipData,d2
	move.l	#CHIP_MEMORY_SIZE,d3
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
	move.w	#$01ff,dmacon(a3)
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
	bsr	SwapChipMemory
	bsr	StartDemo
	bsr	WaitForExitSignal
	bsr	StopDemo
	bsr	SwapChipMemory

	; Restore stack and return
	move.l	a6,a7
	rte

SetInitialState:
	; Turn off audio filter
	bset.b	#1,$bfe001

	; PAL mode, long frames
	move.w	#$0020,beamcon0(a3)
	move.w	#$8000,vposw(a3)

	; Set OCS/ECS defaults
	move.w	#$0200,bplcon0(a3)
	move.w	#$0000,bplcon1(a3)
	move.w	#$0024,bplcon2(a3)
	move.w	#$0000,bplcon3(a3)
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

	; Black background
	move.w	#$0000,bplcon3(a3)
	move.w	#$000,color+0*2(a3)

	; Wait for blitter to finish
	bsr	WaitBlit
	rts

SwapChipMemory:
	lea	ChipData,a0
	lea	CHIP_MEMORY_ADDRESS,a1
	move.l	#CHIP_MEMORY_SIZE,d1
.loop:	move.l	(a0),d0
	move.l	(a1),(a0)+
	move.l	d0,(a1)+
	subq.l	#4,d1
	bgt.b	.loop
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


DosName:
	dc.b	"dos.library",0
GraphicsName:
	dc.b	"graphics.library",0
ChipDataFileName:
	dc.b	"PROGDIR:chip.dat",0
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

	ds.l	4
Stack:

	section	buffer,bss_f

ChipData:
	ds.b	CHIP_MEMORY_SIZE
