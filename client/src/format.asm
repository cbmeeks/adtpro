;
; ADTPro - Apple Disk Transfer ProDOS
; Copyright (C) 2007 by David Schmidt
; david__schmidt at users.sourceforge.net
;
; This program is free software; you can redistribute it and/or modify it 
; under the terms of the GNU General Public License as published by the 
; Free Software Foundation; either version 2 of the License,$ or (at your 
; option) any later version.
;
; This program is distributed in the hope that it will be useful,$ but 
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
; or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License 
; for more details.
;
; You should have received a copy of the GNU General Public License along 
; with this program; if not,$ write to the Free Software Foundation,$ Inc.,$ 
; 59 Temple Place,$ Suite 330,$ Boston,$ MA 02111-1307 USA
;

.include "applechr.i"

;*********************************************************************
;*                                 *            Movie:               *
;*       ProDOS Hyper-FORMAT       *     ProDOS Hyper-FORMAT II      *
;*                                 *           The Return            *
;*     created by Jerry Hewett     *   Modified by Gary Desrochers   *
;*         copyright  1985         *                                 *
;*     Living Legends Software     *        Tryll Software           *
;*                                 *                                 *
;* A Public Domain disk formatting * A Puplic Domain Disk Formatting *
;* routine for the ProDOS Disk Op- * You know the same as -------|   *
;* erating System.  These routines *<----------------------------|   *
;* can be included within your own * Except it now includes code for *
;* software as long as you give us * the 3.5 Disk and the Ram3 Disk. *
;* credit for developing them.     *  Please don't use this for any  *
;*                                 * SmartPort volumes bigger than   *
;*       Updated on: 23Aug85       * 2.1 Meg. Look under Hyper-FORMAT*
;*                                 * in you local BB Library for the *
;*********************************** original code for Hyper-FORMAT  *
;                                  *                                 *
;                                  *      Updated on: 22Dec89        *
;                                  *                                 *
;                                  ***********************************

Home     =  $FC58			;Monitor clear screen and home cursor
DevCnt   =  $BF31			;Prodos device count
DevList  =  $BF32			;List of devices for ProDOS
DevAdr   =  $BF10			;Given slot this is the address of driver
Buffer   =  $0  			;Address pointer for FORMAT data
CH       =  $24 			;Storage for Horizontal Cursor value
IN       =  $200			;Keyboard input buffer
WARMDOS  =  $BE00			;BASIC Warm-start vector
MLI      =  $BF00			;ProDOS Machine Language Interface
LAST     =  $BF30			;Last device accessed by ProDOS
STROUT   =  $DB3A			;Applesoft's string printer
WAIT     =  $FCA8			;Delay routine
CLRLN    =  $FC9C			;Clear Line routine
RDKEY    =  $FD0C			;Character input routine  (read keyboard)
PRBYTE   =  $FDDA			;Print Byte routine (HEX value)
COUT     =  $FDED			;Character output routine (print to screen)
Step0    =  $C080			;Drive stepper motor positions
Step1    =  $C081			;  |      |      |       |
Step2    =  $C082			;  |      |      |       |
Step4    =  $C084			;  |      |      |       |
Step6    =  $C086			;  |      |      |       |
DiskOFF  =  $C088			;Drive OFF  softswitch
DiskON   =  $C089			;Drive ON   softswitch
Select   =  $C08A			;Starting offset for target device
DiskRD   =  $C08C			;Disk READ  softswitch
DiskWR   =  $C08D			;Disk WRITE softswitch
ModeRD   =  $C08E			;Mode READ  softswitch
ModeWR   =  $C08F			;Mode WRITE softswitch
;**********************************************************
; Equates
;**********************************************************
	.org   $5000
HypForm:
	tsx
	stx   Stack
	lda   LAST			;Store current slot/drive # in Slot
	sta   QSlot			;Save Prodos's last device accessed
	jsr   Home			;Clears screen
	jsr   MLI
	.byte $42
	.addr NetParms			;Call for Appletalk which isn't wanted
	bcc   NotError
	cmp   #$01			;Even though everyone said that this
	beq   Reentry			; should happen I never could get it.
	cmp   #$04			;Got this but don't try to change the
	beq   Reentry			; parameter count to 1 or #$%@&*^()
NotError:
	lda   NetDev
	jsr   HexDec
	lda   #<Appletalk		;Prompt to continue or not
	ldy   #>Appletalk		;because Appletalk is installed
	jsr   STROUT
	jsr   GetYN
	beq   Reentry
	jmp   MExit
Reentry:
	jsr   Home			;Clears screen
	lda   #<TargSlt			;Prompt for slot
	ldy   #>TargSlt
	jsr   STROUT
LSlot:
	jsr   RDKEY			;Get a keypress
	cmp   #$B0			;Less than slot #1?
	bcc   LSlot
	cmp   #$B8			;Greater than slot #7?
	bcs   LSlot
	sta   Buffer			;Store SLOT number in Buffer
	jsr   COUT			;Print it on the screen
	lda   #<TargDrv			;Prompt for drive
	ldy   #>TargDrv
	jsr   STROUT
LDrive:
	jsr   RDKEY			;Get a keypress
	cmp   #$B1			;Drive #1?
	beq   LConvert
	cmp   #$B2			;Drive #2?
	bne   LDrive
LConvert:
	sta   Buffer+1			;Store DRIVE number in Buffer+1
	jsr   COUT			;Print it on the screen
	jsr   DOTWO			;Print two carriage returns
	lda   Buffer			;Fetch the SLOT number
	and   #$0F			;Mask off the upper 4 bits
	rol   a			;Move lower 4 bits to upper 4 bits
	rol   a
	rol   a
	rol   a
	sta   Slot			;Store result in FORMAT slot
	tax
	lda   Buffer+1			;Fetch the DRIVE number
	cmp   #$B1			;Does Slot need conditioning?
	beq   Jump5			;Nope
Jump1:
	lda   Slot			;Fetch FORMAT slot
	ora   #$80			;Set MSB to indicate drive #2
	sta   Slot
	tax
Jump5:
	ldy   DevCnt			;Load how many devices
FLoop:
	lda   DevList,y			; since this isn't a sequential
	sta   ListSlot			; list then must go through each one
	and   #$F0			; must also store what is there for later
	cmp   Slot
	beq   ItIsNum
	dey
	bpl   FLoop
	jmp   NoUnit			;Used to be bmi
ItIsNum:
	txa				;Make the slot the indexed register
	lsr   a				; for getting device drive controller
	lsr   a
	lsr   a
	tay
	lda   DevAdr,y			;Get it
	sta   Addr			; and save it
	lda   DevAdr+1,y
	sta   Addr+1
	tay
	and   #$F0			;Next see if it begins with a C0
	cmp   #$C0
	beq   YesSmart			; and if it does is a very smart device
	txa
	cmp   #$B0			;If it isn't smart test for /Ram
	beq   YesRam3
	clc
	ror   a
	ror   a
	ror   a
	ror   a
	and   #$07
	ora   #$C0
	sta   Addr+1			;if it isn't either then treat it as
	jmp   YesSmart1			; smart and save what bank it is in.

YesRam3:
	lda   Addr+1			;If you think it is a /Ram then check
	cmp   #$FF			; the bits that tell you so.
	beq   Loop7			; Does the Address pointer start with FF
	jmp   NoUnit
Loop7:
	lda   Addr			; And end with 00
	cmp   #$00
	beq   Loop8
	jmp   NoUnit
Loop8:
	lda   ListSlot
	and   #$F3
	cmp   #$B3
	beq   Loop9
	jmp   NoUnit
Loop9:
	lda   #<ItIsRam3			;Tell the preson that you think it is a
	ldy   #>ItIsRam3		; /Ram and if they want to continue
	jsr   STROUT
	jsr   GetYN
	bne   Jump2
	jsr   OldName
	jsr   Ram3Form
Jump2:
	jmp   Again
YesSmart:
	tya
	and   #$0F
	rol   a			;Move lower 4 bits to upper 4 bits
	rol   a
	rol   a
	rol   a
	sta   Slot			;Store result in FORMAT slot
YesSmart1:
	lda   Addr+1			;Check signiture bytes in the Cn page
	sta   Buffer+1			; for a smart device.
	lda   #$00
	sta   Buffer
	ldy   #$01
	lda   (Buffer),y
	cmp   #$20
	bne   NoUnit
	ldy   #$03
	lda   (Buffer),y
	bne   NoUnit
	ldy   #$05
	lda   (Buffer),y
	cmp   #$03
	bne   NoUnit
	ldy   #$FF
	lda   (Buffer),y
	cmp   #$00			;Apples DiskII
	beq   DiskII
	cmp   #$FF			;Wrong DiskII
	beq   NoUnit			; must be a smart device.
	ldy   #$07			;Test last signiture byte for the
	lda   (Buffer),y		; Protocol Converter.
	cmp   #$00
	bne   NoUnit			;It isn't so its no device I know.
	lda   #<ItIsSmart		;Tell them you think it is a SmartPort
	ldy   #>ItIsSmart		; device. and ask if they want to Format.
	jsr   STROUT
	jsr   GetYN
	bne   Jump3
	jsr   OldName			;Show old name and ask if proper Disk
	jsr   LName			;Get New name
	jsr   SmartForm			;Jump too routine to format Smart Drive
	lda   ListSlot
	and   #$F0
	sta   Slot
	jsr   CodeWr			;Jump to routine to produce Bit map
	jmp   Catalog			;Write Directory information to the disk
Jump3:	jmp   Again


NoUnit:	lda   #<UnitNone		;Prompt to continue or not Because
	ldy   #>UnitNone		;There is no unit number like that
	jsr   STROUT
	jsr   GetYN
	bne   Jump4
	jmp   Reentry
Jump4:	jmp   MExit

DiskII:
	lda   #<ItsaII			;Tell them you think it is a DiskII
	ldy   #>ItsaII
	jsr   STROUT
	jsr   GetYN
	bne   Jump3
	lda   #$18			;Set VolBlks to 280 ($118)
	ldx   #$01			; Just setting default settings
	ldy   #$00
	sta   VolBlks
	stx   VolBlks+1
	STY   VolBlks+2
	jsr   OldName			;Prompt for proper disk.
	jsr   LName			;Get new name
	jmp   DIIForm			;Format DiskII

LName:	lda   #<VolName
	ldy   #>VolName
	jsr   STROUT
LRdname:
	lda   #$0E			;Reset CH to 14
	sta   CH
	ldx   #$00
	beq   LInput			;Always taken
LBackup:
	cpx   #0  			;Handle backspaces
	beq   LRdname
	dex
	lda   #$88			;<--
	jsr   COUT
LInput:	jsr   RDKEY			;Get a keypress
	cmp   #$88			;Backspace?
	beq   LBackup
	cmp   #$FF			;Delete?
	beq   LBackup
	cmp   #$8D			;C/R is end of input
	beq   LFormat
	cmp   #$AE			;(periods are ok...)
	beq   LStore
	cmp   #$B0			;Less than '0'?
	bcc   LInput
	cmp   #$BA			;Less than ':'?
	bcc   LStore			;Valid. Store the keypress
	and   #$DF			;Force any lower case to upper case
	cmp   #$C0			;Less than 'A'?
	beq   LInput
	cmp   #$DB			;Greater than 'Z'?
	bcs   LInput
LStore:	jsr   COUT			;Print keypress on the screen
	and   #$7F			;Clear MSB
	sta   VOLnam,x			;Store character in VOLnam
	inx
	cpx   #$0E			;Have 15 characters been entered?
	bcc   LInput
LFormat:
	txa				;See if default VOLUME_NAME was taken
	bne   LSetLEN
WLoop:
	lda   Blank,x			;Transfer 'BLANK' to VOLnam
	and   #$7F			;Clear MSB
	sta   VOLnam,x
	inx
	cpx   #$05			;End of transfer?
	bcc   WLoop
	lda   #$13			;Reset CH to 19
	sta   CH
LSetLEN:
	jsr   CLRLN			;Erase the rest of the line
	clc
	txa				;Add $F0 to Volume Name length
	adc   #$F0			;Create STORAGE_TYPE,$ NAME_LENGTH byte
	sta   VolLen
	rts

DIIForm:
	jsr   Format			;Format the disk
	jsr   CodeWr			;Form Bitmap
	lda   #<Verif			;Ask if you want to Verify the Disk
	ldy   #>Verif
	jsr   STROUT
	jsr   GetYN			;Get a Yes or No answer to 'Verify?'
	bne   BIIForm1
	jmp   Verify			;Answer was yes...
BIIForm1:
	jmp   Catalog			;Write Directory information to the disk

CodeWr:	lda   #$81			;Set Opcode to WRITE
	sta   Opcode

;**********************************
;*                                *
;* Write Block0 to disk           *
;*                                *
;**********************************
AskBlk0:
	lda   #<BootCode			;Set MLIbuf to BootCode
	ldy   #>BootCode
	sta   MLIbuf
	STY   MLIbuf+1
	lda   #$00			;Set MLIBlk to 0
	sta   MLIBlk
	sta   MLIBlk+1
	jsr   CallMLI			;Write block #0 to target disk

;**************************************
;*                                    *
;* Fill buffer $6800-$69FF with zeros *
;* and prepare BitMap and Link blocks *
;* for writing to disk                *
;*                                    *
;**************************************
Fill:
	lda   #$05			;Block 5 on Disk
	sta   MLIBlk
	lda   #$00			;Set Buffer,$ MLIbuf to $6800
	ldx   #$68
	sta   MLIbuf
	sta   Buffer
	stx   MLIbuf+1
	stx   Buffer+1
	tay				;Fill $6800-$69FF with zeros
	ldx   #$01			;Fill 2 pages of 256 bytes
LZero:	sta   (Buffer),y
	iny
	bne   LZero
	inc   Buffer+1
	dex
	bpl   LZero
	lda   #$68			;Reset Buffer to $6800
	sta   Buffer+1
	lda   #$05			;Length of DirTbl
	sta   Count
LLink:	ldx   Count
	lda   DirTbl,x			;Move Directory Link values into Buffer
	sta   $6802			;Store next Directory block #
	dex
	lda   DirTbl,x			;Fetch another # from DirTbl
	sta   $6800			;Store previous Directory block #
	dex
	stx   Count
	jsr   CallMLI			;Write Directory Link values to disk
LDec:	dec   MLIBlk			;Decrement MLI block number
	lda   MLIBlk			;See if MLIBlk = 2
	cmp   #$02
	bne   LLink			;Process another Link block

;**********************************
;*                                *
;* Calculate BitMap Size and cndo *
;*                                *
;**********************************
BlkCount:
	lda   VolBlks+1			;Where # of blocks are stored
	ldx   VolBlks
	ldy   VolBlks+2			;Can't deal with block devices this big
	bne   Jump10
	stx   Count+1			;Devide the # of blocks by 8 for bitmap
	lsr   a			; calculation
	ror   Count+1
	lsr   a
	ror   Count+1
	lsr   a
	ror   Count+1
	sta   Count+2
	jmp   BitMapCode
Jump10:	pla				;Remove the address that the routine
	pla				; would have returned to
	lda   #$4D			;Make error Block size to large
	jmp   Died
BitMapCode:
	lda   #%00000001		;Clear first 7 blocks
	sta   (Buffer),y
	ldy   Count+1			;Original low block count value
	bne   Jump11			;if it is 0 then make FF
	dey				;Make FF
	dec   Count+2			;Make 256 blocks less one
	sty   Count+1			;Make FF new low block value
Jump11:
	ldx   Count+2			;High Block Value
	bne   Jump15			;If it isn't equal to 0 then branch
	ldy   Count+1
	jmp   Jump19

Jump15:
	lda   #$69			;Set the adress of the upper part of
	sta   Buffer+1			; Block in bitmap being created
	lda   #%11111111
	ldy   Count+1			;Using the low byte count
Jump20:
	dey
	sta   (Buffer),y		;Store them
	beq   Jump17
	jmp   Jump20
Jump17:
	dey				;Fill in first part of block
	lda   #$68
	sta   Buffer+1
Jump19:	lda   #%11111111
	dey
	sta   (Buffer),y
	cpy   #$01			;Except the first byte.
	beq   Jump18
	jmp   Jump19
Jump18:	rts

;*************************************
;*                                   *
;* VERIFY - Verify each block on the *
;* disk,$ and flag bad ones in BITMAP *
;*                                   *
;*************************************
Verify:
	lda   #$80			;Set Opcode to $80 (READ)
	sta   Opcode
	lda   #$60			;Change Error to an RTS instruction
	sta   Error
	lda   #$00			;Reset MLIbuf to $1000
	ldx   #$10
	sta   MLIbuf
	stx   MLIbuf+1
	sta   Count			;Set Count and Pointer to 0
	sta   Pointer
	sta   LBad			;Set bad block counter to 0
	sta   MLIBlk			;Reset MLIBlk to 0
	sta   MLIBlk+1
LRead:	jsr   CallMLI			;Read a block
	bcs   LError			;Update BitMap if error occurs
LIncBlk:
	clc				;Add 1 to MLIBlk
	inc   MLIBlk
	bne   LCheck
	inc   MLIBlk+1
LCheck:
	inc   Count			;Add 1 to BitMap counter
	lda   Count			;If Count > 7 then add 1 to Pointer
	cmp   #$08
	bcc   MDone
	lda   #$00			;Reset Count to 0
	sta   Count
	inc   Pointer			;Add 1 to Pointer offset value
MDone:	ldx   MLIBlk			;See if we've read 280 blocks yet
	lda   MLIBlk+1
	beq   LRead
	cpx   #$18			;Greater than $118 (280) blocks read?
	beq   LResult			;Finished. Display results of VERIFY
	bne   LRead			;Go get another block
LError:	ldx   Count			;Use Count as offset into MapTbl
	lda   BitTbl,x			;Fetch value for bad block number
	ldy   Pointer			;Use Pointer as offset into Buffer
	and   (Buffer),y		;Mask value against BitMap value
	sta   (Buffer),y		;Store new BitMap value in Buffer
	clc
	dec   VolBlks			;Decrement # of blocks available
	bne   LIncBad
	dec   VolBlks+1
LIncBad:
	inc   LBad			;Add 1 to # of bad blocks found
	jmp   LIncBlk			;Get the next block on the disk
LResult:
	lda   #$EA			;Change Error back to a : instruction
	sta   Error
	lda   LBad			;Find out if there were any bad blocks
	beq   LGood
	jsr   HexDec			;Convert hex number into decimal
	ldx   #$00
BLoop:	lda   IN,x			;Print the decimal gequivalent of LBad
	cmp   #$31			;Don't print zeros...
	bcc   MNext
	jsr   COUT
MNext:	inx
	cpx   #$03			;End of number?
	bcc   BLoop
	lda   #<Bad
	ldy   #>Bad
	jsr   STROUT
	jmp   Catalog			;Write BitMap and Links to the disk
LGood:	lda   #<Good
	ldy   #>Good
	jsr   STROUT
	jmp   Catalog
LBad:	.res 1    			;Number of bad blocks found

;*************************************
;*                                   *
;* Catalog - Build a Directory Track *
;*                                   *
;*************************************
Catalog:
	lda   #$81			;Change Opcode to $81 (WRITE)
	sta   Opcode
	lda   #$00			;Reset MLIbuf to $6800
	ldx   #$68
	sta   MLIbuf
	stx   MLIbuf+1
	ldx   #$06			;Write Buffer (BitMap) to block #6 on the disk
	stx   MLIBlk
	sta   MLIBlk+1
	jsr   Call2MLI			; Call for time and date
	jsr   MLI
	.byte $82
	.addr 0000
	lda   $BF90			; Get them and save them into the
	sta   Datime			; Directory to be written.
	lda   $BF91
	sta   Datime+1
	lda   $BF92
	sta   Datime+2
	lda   $BF93
	sta   Datime+3
	ldy   #$2A			;Move Block2 information to $6800
CLoop:	lda   Block2,y
	sta   (Buffer),y
	dey
	bpl   CLoop
	lda   #$02			;Write block #2 to the disk
	sta   MLIBlk
	jsr   Call2MLI
Again:
	lda   #<Nuther			;Display 'Format another' string
	ldy   #>Nuther
	jsr   STROUT
	jsr   GetYN			;Get a Yes or No answer
	bne   MExit			;Answer was No...
	jmp   Reentry			;Format another disk
MExit:	jsr   DOTWO			;Two final carriage returns...
	lda   QSlot
	sta   LAST
	ldx   Stack			;Just because I am human to and might
	txs				;have messed up also.
	jmp   WARMDOS			;Exit to BASIC
Call2MLI:
	jsr   CallMLI
	rts

;***************************
;*                         *
;* GetYN - Get a Yes or No *
;* answer from the user    *
;*                         *
;***************************
GetYN:
	jsr   RDKEY			;Get a keypress
	and   #$DF			;Mask lowercase
	cmp   #$D9			;is it a Y?
	beq   LShow
	lda   #$BE			;Otherwise default to "No"
LShow:	jsr   COUT			;Print char,$ Z flag contains status
	cmp   #$D9			;Condition flag
	rts

;*************************************
;*                                   *
;* CallMLI - Call the MLI Read/Write *
;* routines to transfer blocks to or *
;* from memory                       *
;*                                   *
;*************************************
CallMLI:
	jsr   MLI 			;Call the ProDOS Machine Langauge Interface
Opcode:	.byte $81 			;Default MLI opcode = $81 (WRITE)
	.addr Parms
	bcs   Error
	rts
Error:      				;(this will be changed to RTS by VERIFY)
	pla
	pla
	pla
	pla
	jmp   Died

;**************************************
;*                                    *
;* DOTWO - Print two carriage returns *
;*                                    *
;**************************************
DOTWO:
	lda   #$8D			;(we don't need an explanation,$ do we?)
	jsr   COUT
	jsr   COUT
	rts

;***********************************
;*                                 *
;* Hexdec - Convert HEX to decimal *
;*                                 *
;***********************************
HexDec:
	sta   IN+20			;Store number in Keyboard Input Buffer
	lda   #$00
	sta   IN+21
	ldy   #$02			;Result will be three digits long
DLoop:	ldx   #$11			;16 bits to process
	lda   #$00
	clc
LDivide:
	rol   a
	cmp   #$0A			;Value > or = to 10?
	bcc   LPlus
	SBC   #$0A			;Subtract 10 from the value
LPlus:	rol   IN+20			;Shift values in IN+20,$ IN+21 one bit left
	rol   IN+21
	dex
	bne   LDivide
	ora   #$B0			;Convert value to high ASCII character
	sta   IN,y			;Store it in the input buffer
	sta   NetNum,y
	dey
	bpl DLoop
	rts

;***********************************
;*                                 *
;* FORMAT - Format the target disk *
;*                                 *
;***********************************
Format:
	php
	sei
	lda   Slot			;Fetch target drive SLOTNUM value
	pha				;Store it on the stack
	and   #$70			;Mask off bit 7 and the lower 4 bits
	sta   SlotF			;Store result in FORMAT slot storage
	tax				;Assume value of $60 (drive #1)
	pla				;Retrieve value from the stack
	bpl   LDrive1			;If < $80 the disk is in drive #1
	inx				;Set X offset to $61 (drive #2)
LDrive1:
	lda   Select,x			;Set softswitch for proper drive
	ldx   SlotF			;Set X offset to FORMAT slot/drive
	lda   DiskON,x			;Turn the drive on
	lda   ModeRD,x			;Set Mode softswitch to READ
	lda   DiskRD,x			;Read a byte
	lda   #$23			;Assume head is on track 35
	sta   TRKcur
	lda   #$00			;Destination is track 0
	sta   TRKdes
	jsr   Seek			;Move head to track 0
	ldx   SlotF			;Turn off all drive phases
	lda   Step0,x
	lda   Step2,x
	lda   Step4,x
	lda   Step6,x
	lda   TRKbeg			;Move TRKbeg value (0) to Track
	sta   Track
	jsr   Build			;Build a track in memory at $6700

;*******************************
;*                             *
;* WRITE - Write track to disk *
;*                             *
;*******************************
Write:
	jsr   Calc			;Calculate new track/sector/checksum values
	jsr   Trans			;Transfer track in memory to disk
	bcs   DiedII			;If carry set,$ something died
MInc:	inc   Track			;Add 1 to Track value
	lda   Track			;Is Track > ending track # (TRKend)?
	cmp   TRKend
	beq   LNext			;More tracks to FORMAT
	bcs   Done			;Finished.  Exit FORMAT routine
LNext:	sta   TRKdes			;Move next track to FORMAT to TRKdes
	jsr   Seek			;Move head to that track
	jmp   Write			;Write another track
Done:	ldx   SlotF			;Turn the drive off
	lda   DiskOFF,x
	plp
	rts				;FORMAT is finished. Return to calling routine
DiedII:	pha				;Save MLI error code on the stack
	jsr   Done
	pla				;Retrieve error code from the stack
	jmp   Died			;Prompt for another FORMAT...

;**************************************
;*                                    *
;* Died - Something awful happened to *
;* the disk or drive. Die a miserable *
;* death...                           *
;*                                    *
;**************************************
Died:
	cmp   #$4D			;Save MLI error code on the stack
	beq   RangeError
	cmp   #$27
	beq   DriveOpen
	cmp   #$2F
	beq   DiskError
	cmp   #$2B
	beq   Protected
	jmp   NoDied
RangeError:
	lda   #<TooLarge
	ldy   #>TooLarge
	jmp   DiedOut
DiskError:
	lda   #<NoDisk
	ldy   #>NoDisk
	jmp   DiedOut
DriveOpen:
	lda   #<Dead
	ldy   #>Dead
	jmp   DiedOut
Protected:
	lda   #<Protect
	ldy   #>Protect
	jmp   DiedOut
NoDied:	pha				;Save MLI error code on the stack
	lda   #<UnRecog
	ldy   #>UnRecog
	jsr   STROUT
	pla				;Retrieve error code from the stack
	jsr   PRBYTE			;Print the MLI error code
	jmp   Again
DiedOut:
	jsr   STROUT
	jmp   Again			;Prompt for another FORMAT...

;************************************
;*                                  *
;* TRANS - Transfer track in memory *
;* to target device                 *
;*                                  *
;************************************
Trans:
	lda   #$00			;Set Buffer to $6700
	ldx   #$67
	sta   Buffer
	stx   Buffer+1
	ldy   #$32			;Set Y offset to 1st sync byte (max=50)
	ldx   SlotF			;Set X offset to FORMAT slot/drive
	sec				;(assum the disk is write protected)
	lda   DiskWR,x			;Write something to the disk
	lda   ModeRD,x			;Reset Mode softswitch to READ
	bmi   LWRprot			;If > $7F then disk was write protected
	lda   #$FF			;Write a sync byte to the disk
	sta   ModeWR,x
	cmp   DiskRD,x
	nop				;(kill some time for WRITE sync...)
	jmp   LSync2
LSync1:	eor   #$80			;Set MSB,$ converting $7F to $FF (sync byte)
	nop				;(kill time...)
	nop
	jmp   MStore
LSync2:	pha				;(kill more time... [ sheesh! ])
	pla
LSync3:	lda   (Buffer),y		;Fetch byte to WRITE to disk
	cmp   #$80			;Is it a sync byte? ($7F)
	bcc   LSync1			;Yep. Turn it into an $FF
	nop
MStore:	sta   DiskWR,x			;Write byte to the disk
	cmp   DiskRD,x			;Set Read softswitch
	iny				;Increment Y offset
	bne   LSync2
	inc   Buffer+1			;Increment Buffer by 255
	bpl   LSync3			;If < $8000 get more FORMAT data
	lda   ModeRD,x			;Restore Mode softswitch to READ
	lda   DiskRD,x			;Restore Read softswitch to READ
	clc
	rts
LWRprot:
	clc				;Disk is write protected! (Nerd!)
	jsr   Done			;Turn the drive off
	lda   #$2B
	pla
	pla
	pla
	pla
	jmp   Died			;Prompt for another FORMAT...

;************************************
;*                                  *
;* BUILD - Build GAP1 and 16 sector *
;* images between $6700 and $8000   *
;*                                  *
;************************************
Build:
	lda   #$10			;Set Buffer to $6710
	ldx   #$67
	sta   Buffer
	stx   Buffer+1
	ldy   #$00			;(Y offset always zero)
	ldx   #$F0			;Build GAP1 using $7F (sync byte)
	lda   #$7F
	sta   LByte
	jsr   LFill			;Store sync bytes from $6710 to $6800
	lda   #$10			;Set Count for 16 loops
	sta   Count
LImage:	ldx   #$00			;Build a sector image in the Buffer area
ELoop:	lda   LAddr,x			;Store Address header,$ info & sync bytes
	beq   LInfo
	sta   (Buffer),y
	jsr   LInc			;Add 1 to Buffer offset address
	inx
	bne   ELoop
LInfo:	ldx   #$AB			;Move 343 bytes into data area
	lda   #$96			;(4&4 encoded version of hex $00)
	sta   LByte
	jsr   LFill
	ldx   #$AC
	jsr   LFill
	ldx   #$00
YLoop:	lda   LData,x 		;Store Data Trailer and GAP3 sync bytes
	beq   LDecCnt
	sta   (Buffer),y
	jsr   LInc
	inx
	bne   YLoop
LDecCnt:
	clc
	dec   Count
	bne   LImage
	rts				;Return to write track to disk (WRITE)
LFill:	lda   LByte
	sta   (Buffer),y		;Move A register to Buffer area
	jsr   LInc			;Add 1 to Buffer offset address
	dex
	bne   LFill
	rts
LInc:	clc
	inc   Buffer			;Add 1 to Buffer address vector
	bne   LDone
	inc   Buffer+1
LDone:	rts

;***********************************
;*                                 *
;* CALC - Calculate Track,$ Sector,$ *
;* and Checksum values of the next *
;* track using 4&4 encoding        *
;*                                 *
;***********************************
Calc:
	lda   #$03			;Set Buffer to $6803
	ldx   #$68
	sta   Buffer
	stx   Buffer+1
	lda   #$00			;Set Sector to 0
	sta   Sector
ZLoop:	ldy   #$00			;Reset Y offset to 0
	lda   #$FE			;Set Volume # to 254 in 4&4 encoding
	jsr   LEncode
	lda   Track			;Set Track,$ Sector to 4&4 encoding
	jsr   LEncode
	lda   Sector
	jsr   LEncode
	lda   #$FE			;Calculate the Checksum using 254
	eor   Track
	eor   Sector
	jsr   LEncode
	clc				;Add 385 ($181) to Buffer address
	lda   Buffer
	adc   #$81
	sta   Buffer
	lda   Buffer+1
	adc   #$01
	sta   Buffer+1
	inc   Sector			;Add 1 to Sector value
	lda   Sector			;If Sector > 16 then quit
	cmp   #$10
	bcc   ZLoop
	rts				;Return to write track to disk (WRITE)
LEncode:
	pha				;Put value on the stack
	lsr   a   			;Shift everything right one bit
	ora   #$AA			;OR it with $AA
	sta   (Buffer),y		;Store 4&4 result in Buffer area
	iny
	pla				;Retrieve value from the stack
	ora   #$AA			;OR it with $AA
	sta   (Buffer),y		;Store 4&4 result in Buffer area
	iny
	rts

;*************************************
;*                                   *
;* Seek - Move head to desired track *
;*                                   *
;*************************************
Seek:
	lda   #$00			;Set InOut flag to 0
	sta   LInOut
	lda   TRKcur			;Fetch current track value
	SEC
	SBC   TRKdes			;Subtract destination track value
	beq   LExit			;If = 0 we're done
	bcs   LMove
	eor   #$FF			;Convert resulting value to a positive number
	adc   #$01
LMove:	sta   Count			;Store track value in Count
	rol   LInOut			;Condition InOut flag
	lsr   TRKcur			;Is track # odd or even?
	rol   LInOut			;Store result in InOut
	asl   LInOut			;Shift left for .Table offset
	ldy   LInOut
ALoop:	lda   LTable,y			;Fetch motor phase to turn on
	jsr   phase			;Turn on stepper motor
	lda   LTable+1,y		;Fetch next phase
	jsr   phase			;Turn on stepper motor
	tya
	eor   #$02			;Adjust Y offset into LTable
	tay
	dec   Count			;Subtract 1 from track count
	bne   ALoop
	lda   TRKdes			;Move current track location to TRKcur
	sta   TRKcur
LExit:	rts				;Return to calling routine

;**********************************
;*                                *
;* phaSE - Turn the stepper motor *
;* on and off to move the head    *
;*                                *
;**********************************
phase:
	ora   SlotF			;OR Slot value to phaSE
	tax
	lda   Step1,x			;phaSE on...
	lda   #$56			;20 ms. delay
	jsr   WAIT
	lda   Step0,x			;phaSE off...
	rts

;**********************************
;*                                *
;* Format a Ram3 device.          *
;*                                *
;**********************************
Ram3Form:
	php
	sei
	lda   #3  			;Format Request number
	sta   $42
	lda   Slot			;Slot of /Ram
	sta   $43
	lda   #$00			;Buffer space if needed Low byte
	sta   $44
	lda   #$67			; and high byte
	sta   $45

	lda   $C08B			;Read and write Ram,$ using Bank 1
	lda   $C08B

	jsr   Ram3Dri
	bit   $C082			;Read ROM,$ use Bank 2(Put back on line)
	bcs   Ram3Err
	plp
	rts

Ram3Dri:
	jmp   (Addr)
Ram3Err:
	tax
	plp
	pla
	pla
	txa
	jmp   Died

;**********************************
;*                                *
;* Format a SmartPort Device      *
;*                                *
;**********************************
SmartForm:
	php
	sei
	lda   #0			;Request Protocol converter for a Status
	sta   $42
	lda   ListSlot			;Give it the ProDOS Slot number
	and   #$F0
	sta   $43
	lda   #$00			; Give it a buffer may not be needed by
	sta   $44			; give it to it anyways
	lda   #$68
	sta   $45
	lda   #$03			;The Blocks of Device
	sta   $46
	jsr   SmartDri
	txa				;Low in X register
	sta   VolBlks			; Save it
	tya				;High in Y register
	sta   VolBlks+1			; Save it
	lda   #$00
	sta   VolBlks+2
	lda   #3  			;Give Protocol Converter a Format Request
	sta   $42 			;Give it Slot number
	lda   ListSlot
	and   #$F0
	sta   $43
	lda   #$00			;Give a buffer which probably won't be
	sta   $44 			; used.
	lda   #$68
	sta   $45

	jsr   SmartDri
	bcs   SmartErr
	plp
	rts

SmartDri:
	jmp   (Addr)
SmartErr:
	tax
	plp
	pla
	pla
	txa
	jmp   Died

;**********************************
;*                                *
;* Is there an old name?          *
;*                                *
;**********************************
OldName:
	lda   ListSlot
	and   #$F0
	sta   Info+1
	jsr   MLI
	.byte $C5
	.addr Info
	lda   VolLen
	and   #$0F
	bne   OldName1
	lda   VolLen+1
	cmp   #$28
	bne   OldError
	pla
	pla
	jmp   NoUnit
OldName1:
	sta   VolLen
	lda   #<TheOld1
	ldy   #>TheOld1
	jsr   STROUT
	lda   #<VolLen			;Get Name Length
	ldy   #>VolLen
	jsr   STROUT			;Print old name
	lda   #<TheOld2
	ldy   #>TheOld2
	jsr   STROUT
	jsr   GetYN
	beq   OldError
	pla
	pla
	jmp   Again
OldError:
	rts

;*************************
;*                       *
;* Variable Storage Area *
;*                       *
;*************************
Info:
	.byte $02
	.res 1
	.addr VolLen
Parms:	.byte $03			;Parameter count = 3
Slot:	.byte $60			;Default to S6,$D1
MLIbuf:	.addr BootCode			;Default buffer address
MLIBlk:	.byte $00,$00			;Default block number of 0
QSlot:	.res 1				;Quit Slot number
ListSlot:
	.res 1				;Saving the slot total from the list
Addr:	.res 2
NetParms:
	.byte $00
	.byte $2F			;Command for FIListSessions
	.addr $0000			;Appletalk Result Code returned here
	.addr $0100			;Length of string
	.addr $6700			;Buffer low word
	.addr $0000			;Buffer High word
NetDev:	.byte $00			;Number of entries returned here
LByte:	.res 1				;Storage for byte value used in Fill
LAddr:	.byte $D5,$AA,$96 ; dc    H'D5 AA 96'              ;Address header
	.byte $AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA ;dc    8i1'$AA'                 ;Volume #,$ Track,$ Sector,$ Checksum
	.byte $DE,$AA,$EB		;Address trailer
	.byte $7f,$7f,$7f,$7f,$7f,$7f	;GAP2 sync bytes
	.byte $D5,$AA,$AD		;Buffer header
	.byte $00			;End of Address information
LData:	.byte $DE,$AA,$EB		;Data trailer
	.byte $7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f  ;GAP3 sync bytes
	.byte $00     			;End of Data information

LInOut:	.res 1   			;Inward/Outward phase for stepper motor
LTable:	.byte $02,$04,$06,$00		;Phases for moving head inward
	.byte $06,$04,$02,$00		;   |    |    |      |  outward

TargSlt:
	.byte $8D,$8D
	ascz "Format disk in SLOT "
TargDrv:
	ascz " DRIVE "
VolName:
	.byte $8d
	asc "Volume name: /"
Blank:	asc "BLANK"
	ascz "__________"
Verif:	.byte $8d,$8d
	asc "Certify disk and mark any bad blocks in "
	ascz "the Volume BitMap as unusable? (Y/N): "
TheOld1:
	.byte $8d
	asc "Do You Want To Write Over"
	.byte $8D,$A0,$AF,$00
TheOld2:
	.byte $A0,$BF
	ascz " (Y/N)"
UnRecog:
	.byte $8D
	ascz "Unrecognizable ERROR = "
Dead:	.byte $8D
	ascz "-- Check disk or drive door --"
Protect:
	.byte $8D
	ascz "Disk is write protected, you bozo!"
Bad:	.byte $8d,$8d
	ascz " bad block(s) marked"
Good:	.byte $8d,$8d
	ascz "Disk is error-free"
NoDisk:	.byte $8D
	ascz "No Disk in the drive"
Nuther:	.byte $8d,$8d
	ascz "Format another disk? (Y/N): "
TooLarge:
	.byte $8D
	ascz "Unit Size Is To Large For this Program"
UnitNone:
	.byte $8d
	asccr "No Unit in that slot and drive"
	ascz  "Format another disk? (Y/N): "
ItIsRam3:
	.byte $8d
	asccr "This is a Ram3 disk"
	ascz  "Continue with Format? (Y/N): "
ItsaII:	.byte $8D
	asc "This is a Disk II"
	.byte $8D
	ascz "Continue with Format? (Y/N): "
ItIsSmart:
	.byte $8D
	asccr "This is a SmartPort device"
	ascz  "Continue with Format? (Y/N): "
Appletalk:
	.byte $8D
	asc "Number of Appletalk devices is = "
NetNum:
	.byte $00,$00,$00,$8D
	asccr "AppleTalk is installed this Program may"
	asccr "not work properly do you want to"
	ascz  "Continue (Y/N)"
Block2:	.byte $00,$00,$03,$00
VolLen:	.res 1				;$F0 + length of Volume Name
VOLnam:	.res 15 ; .byte 15, 28 ; DS    15           28          ;Volume Name,$ Reserved,$ Creation,$ Version
Reserved:
	.res 6
UpLowCase:
	.byte $00,$00
Datime:	.res 4
Version:
	.byte 01
	.byte $00,$C3,$27,$0D
	.byte $00,$00,$06,$00
VolBlks:
	.res 3				;Number of blocks available
DirTbl:	.byte $02,$04,$03		;Link list for directory blocks
	.byte $05,$04,$00
BitTbl:	.byte $7f ; dc    B'01111111'	;BitMap mask for bad blocks
	.byte $bf ; dc    B'10111111'
	.byte $df ; dc    B'11011111'
	.byte $ef ; dc    B'11101111'
	.byte $f7 ; dc    B'11110111'
	.byte $fb ; dc    B'11111011'
	.byte $fd ; dc    B'11111101'
	.byte $fe ; dc    B'11111110'
Stack:	.res 1	 			;Entrance stack pointer
Count:	.res 3	 			;General purpose counter/storage byte
Pointer:
	.res 2	 			;Storage for track count (8 blocks/track)
Track:	.res 2	 			;Track number being FORMATted
Sector:	.res 2				;Current sector number (max=16)
SlotF:	.res 2				;Slot/Drive of device to FORMAT
TRKcur:	.res 2				;Current track position
TRKdes:	.res 2 				;Destination track position
TRKbeg:	.byte 00			;Starting track number
TRKend:	.byte 35			;Ending track number
BootCode:
	.byte $01,$38,$B0,$03,$4C,$32,$A1,$86,$43,$C9,$03,$08,$8A,$29,$70,$4A,$4A,$4A,$4A,$09,$C0,$85,$49,$A0
	.byte $FF,$84,$48,$28,$C8,$B1,$48,$D0,$3A,$B0,$0E,$A9,$03,$8D,$00,$08,$E6,$3D,$A5,$49,$48,$A9,$5B,$48
	.byte $60,$85,$40,$85,$48,$A0,$63,$B1,$48,$99,$94,$09,$C8,$C0,$EB,$D0,$F6,$A2,$06,$BC,$1D,$09,$BD,$24
	.byte $09,$99,$F2,$09,$BD,$2B,$09,$9D,$7F,$0A,$CA,$10,$EE,$A9,$09,$85,$49,$A9,$86,$A0,$00,$C9,$F9,$B0
	.byte $2F,$85,$48,$84,$60,$84,$4A,$84,$4C,$84,$4E,$84,$47,$C8,$84,$42,$C8,$84,$46,$A9,$0C,$85,$61,$85
	.byte $4B,$20,$12,$09,$B0,$68,$E6,$61,$E6,$61,$E6,$46,$A5,$46,$C9,$06,$90,$EF,$AD,$00,$0C,$0D,$01,$0C
	.byte $D0,$6D,$A9,$04,$D0,$02,$A5,$4A,$18,$6D,$23,$0C,$A8,$90,$0D,$E6,$4B,$A5,$4B,$4A,$B0,$06,$C9,$0A
	.byte $F0,$55,$A0,$04,$84,$4A,$AD,$02,$09,$29,$0F,$A8,$B1,$4A,$D9,$02,$09,$D0,$DB,$88,$10,$F6,$29,$F0
	.byte $C9,$20,$D0,$3B,$A0,$10,$B1,$4A,$C9,$FF,$D0,$33,$C8,$B1,$4A,$85,$46,$C8,$B1,$4A,$85,$47,$A9,$00
	.byte $85,$4A,$A0,$1E,$84,$4B,$84,$61,$C8,$84,$4D,$20,$12,$09,$B0,$17,$E6,$61,$E6,$61,$A4,$4E,$E6,$4E
	.byte $B1,$4A,$85,$46,$B1,$4C,$85,$47,$11,$4A,$D0,$E7,$4C,$00,$20,$4C,$3F,$09,$26,$50,$52,$4F,$44,$4F
	.byte $53,$20,$20,$20,$20,$20,$20,$20,$20,$20,$A5,$60,$85,$44,$A5,$61,$85,$45,$6C,$48,$00,$08,$1E,$24
	.byte $3F,$45,$47,$76,$F4,$D7,$D1,$B6,$4B,$B4,$AC,$A6,$2B,$18,$60,$4C,$BC,$09,$A9,$9F,$48,$A9,$FF,$48
	.byte $A9,$01,$A2,$00,$4C,$79,$F4,$20,$58,$FC,$A0,$1C,$B9,$50,$09,$99,$AE,$05,$88,$10,$F7,$4C,$4D,$09
	.byte $AA,$AA,$AA,$A0,$D5,$CE,$C1,$C2,$CC,$C5,$A0,$D4,$CF,$A0,$CC,$CF,$C1,$C4,$A0,$D0,$D2,$CF,$C4,$CF
	.byte $D3,$A0,$AA,$AA,$AA,$A5,$53,$29,$03,$2A,$05,$2B,$AA,$BD,$80,$C0,$A9,$2C,$A2,$11,$CA,$D0,$FD,$E9
	.byte $01,$D0,$F7,$A6,$2B,$60,$A5,$46,$29,$07,$C9,$04,$29,$03,$08,$0A,$28,$2A,$85,$3D,$A5,$47,$4A,$A5
	.byte $46,$6A,$4A,$4A,$85,$41,$0A,$85,$51,$A5,$45,$85,$27,$A6,$2B,$BD,$89,$C0,$20,$BC,$09,$E6,$27,$E6
	.byte $3D,$E6,$3D,$B0,$03,$20,$BC,$09,$BC,$88,$C0,$60,$A5,$40,$0A,$85,$53,$A9,$00,$85,$54,$A5,$53,$85
	.byte $50,$38,$E5,$51,$F0,$14,$B0,$04,$E6,$53,$90,$02,$C6,$53,$38,$20,$6D,$09,$A5,$50,$18,$20,$6F,$09
	.byte $D0,$E3,$A0,$7F,$84,$52,$08,$28,$38,$C6,$52,$F0,$CE,$18,$08,$88,$F0,$F5,$BD,$8C,$C0,$10,$FB,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00