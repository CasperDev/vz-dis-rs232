; z80dasm 1.1.2
; command line: z80dasm --address --labels --source --origin=0x4000 --output=src/RS232v1.6.asm bin/RS232v1.6.bin

;**********************************************************************
; Used System Routines/Hardware
;----------------------------------------------------------------------

GetPrtStatus		equ		$05c4						; Get Printer status
SendToPrinter		equ		$058d						; Send char to printer
SendCRToPrt			equ		$3ae2						; Send CR to printer
PlayBeep			equ		$3450						; Play beep sound
VZLATCH				equ		$6800
SCREEN				equ		$7000						; Screen memory


;**********************************************************************
; Custom RS232 Hardware
;----------------------------------------------------------------------

RSINPUT				equ		$5000						; Serial input
RSOUTPUT			equ		$5800						; Serial output


;**********************************************************************
; ROM MAGIC
;----------------------------------------------------------------------

	org		$4000
	defb 	$aa,$55,$e7,$18

;**********************************************************************
; Initialization
;----------------------------------------------------------------------
	jp	INIT				; start initialization							;4004	c3 84 41 	. . 

;**********************************************************************
; Texts
;----------------------------------------------------------------------

TxtOn:
	db	"ON "									; text						;4007	4f 4e 20  	F 
TxtOff:
	db	"OFF"									; text						;400a	4f 46 46 	F "
TxtFull:
	db	"FULL"									; text						;400d	46 55 4c 4c 	L 
TxtHalf:
	db 	"HALF"									; text						;4011	48 41 4c 46 	F 
TxtMenu:
	db	$0c										; Clear screen char			;4015	0c 	. 
	db 	"VZ-200/300 RS-232 - VERSION 1.6",$d								;4016	56 5a 2d 32 30 30 2f 33 30 30 20 52 53 2d 32 33 32 20 2d 20 56 45 52 53 49 4f 4e 20 31 2e 36 0d 	. 
	db 	"(C) 1987 DICK SMITH ELECTRONICS",$d								;4036	28 43 29 20 31 39 38 37 20 44 49 43 4b 20 53 4d 49 54 48 20 45 4c 45 43 54 52 4f 4e 49 43 53 0d 	. 
	db 	"-------------------------------",$d								;4056	2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 2d 0d 	. 
	db	"0] ENTER TERMINAL",$d												;4076	30 5d 20 45 4e 54 45 52 20 54 45 52 4d 49 4e 41 4c 0d 	. 
	db 	"1] FULL/HALF DUPLEX:",0											;4088	31 5d 20 46 55 4c 4c 2f 48 41 4c 46 20 44 55 50 4c 45 58 3a 00	X 
TxtConfig:
	db 	"FULL",$d															;409d	46 55 4c 4c 0d 	. 
	db	"2] TOGGLE PRINTER  :OFF",$d										;40a2	32 5d 20 54 4f 47 47 4c 45 20 50 52 49 4e 54 45 52 20 20 3a 4f 46 46 0d 	. 
	db	"3] SET # DATA BITS :8  ",$d										;40ba	33 5d 20 53 45 54 20 23 20 44 41 54 41 20 42 49 54 53 20 3a 38 20 20 0d 	  . 
	db	"4] SET # STOP BITS :1  ",$d										;40d2	34 5d 20 53 45 54 20 23 20 53 54 4f 50 20 42 49 54 53 20 3a 31 20 20 0d 	. 
	db	"5] SET PARITY      :N  ",$d										;40ea	35 5d 20 53 45 54 20 50 41 52 49 54 59 20 20 20 20 20 20 3a 4e 20 20 0d 	  . 
	db	"6] ADD LF TO CR    :OFF",$d										;4102	36 5d 20 41 44 44 20 4c 46 20 54 4f 20 43 52 20 20 20 20 3a 4f 46 46 0d 	. 
	db	$d																	;411a	0d 	. 
	db	"******* WHEN IN TERMINAL *******"									;411b	2a 2a 2a 2a 2a 2a 2a 20 57 48 45 4e 20 49 4e 20 54 45 52 4d 49 4e 41 4c 20 2a 2a 2a 2a 2a 2a 2a 
	db	"*  SHIFT - X TO EXIT TERMINAL  *"									;413b 	2a 20 20 53 48 49 46 54 20 2d 20 58 20 54 4f 20 45 58 49 54 20 54 45 52 4d 49 4e 41 4c 20 20 2a	    
	db	"********************************",0	 							;415b	2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 2a 00 	. 
	db  0,0,0,0,0,0,0,0														;417c	00 00 00 00 00 	. 

;**********************************************************************
; Program state Variables
;----------------------------------------------------------------------

PRINTER			equ		$80df						; 0-Printer Off, 1-Printer On
DUPLEX 			equ		$80e0						; 0-FullDuplex, 1-HalfDuplex
APPENDLF		equ		$80e1						; 0-dont add, 1-add LF after CR
LASTKEY			equ		$80e2						; last key pressed
KEYFLAGS		equ		$80e3						; bit 1: SHIFT, bit 2: CTRL
CURSORCOL		equ		$80e4						
CURSORADR		equ		$80e5
OffScreen		equ		$8000
ScrDUPLEX		equ		OffScreen+0
ScrPrinter		equ		OffScreen+25
ScrDataBits		equ		OffScreen+49
ScrStopBits		equ		OffScreen+73
ScrParity		equ		OffScreen+97
ScrAppendLF		equ		OffScreen+121


;**********************************************************************
; Program Code
;----------------------------------------------------------------------
INIT:
	di						; disble interrupts								;4184	f3 	. 
	ld sp,$9000				; safe top memory								;4185	31 00 90 	1 . . 
; -- copy screen data with changing settings to writeable memory 8000 .. 80e6
;    from addresses 409d .. 4183 
	ld hl,TxtConfig			; src - address to copy from					;4188	21 9d 40 	! . @ 
	ld de,OffScreen			; dst - address to copy  to						;418b	11 00 80 	. . . 
	ld bc,231				; 231 bytes to copy								;418e	01 e7 00 	. . . 
	ldir					; copy config texts								;4191	ed b0 	. . 

MenuLoop:
	ld a,(APPENDLF)			; a - current value APPENDLF 					;4193	3a e1 80 	: . . 
	push af					; save current value							;4196	f5 	. 
	ld a,1					; a=1 - append LF after CR 						;4197	3e 01 	> . 
	ld (APPENDLF),a			; set temp value 								;4199	32 e1 80 	2 . . 
; -- display menu on Screen
	ld hl,TxtMenu			; 1st part of Menu Screen						;419c	21 15 40 	! . @ 
	call PrintStr			; print on screen								;419f	cd 4d 43 	. M C 
	ld hl,OffScreen			; 2nd part of Menu								;41a2	21 00 80 	! . . 
	call PrintStr			; print on screen 								;41a5	cd 4d 43 	. M C 
	pop af					; restore saved value 							;41a8	f1 	. 
	ld (APPENDLF),a			; restore saved APPENDLF value 					;41a9	32 e1 80 	2 . . 
	call PlayBeep			; Play short beep sound							;41ac	cd 50 34 	. P 4 
	ld hl,MenuLoop			; address of code to return 					;41af	21 93 41 	! . A 
	push hl					; set as return address							;41b2	e5 	. 
WaitMenuKey:
	call GetKeyPress		; get key pressed								;41b3	cd 66 44 	. f D 
	or a					; any key pressed?								;41b6	b7 	. 
	jr z,WaitMenuKey		; no - wait for key pressed	---------------		;41b7	28 fa 	( . 
	sub '0'					; is it < '0' ?									;41b9	d6 30 	. 0 
	jr c,WaitMenuKey		; yes - wrong, wait for other key pressed		;41bb	38 f6 	8 . 
	cp 7					; is it > '7' ?									;41bd	fe 07 	. . 
	jr nc,WaitMenuKey		; yes - wrong, wait for other key pressed		;41bf	30 f2 	0 . 
	ld hl,ActionsPtrs		; table with pointers to routines 0...7			;41c1	21 ce 41 	! . A 
	add a,a					; a = a*2 (addresses are 16bit)					;41c4	87 	. 
	ld e,a					; e - offset in Actions Table					;41c5	5f 	_ 
	ld d,0					; de - offset in Actions table					;41c6	16 00 	. . 
	add hl,de				; hl - address of pointer to Action 			;41c8	19 	. 
	ld e,(hl)				; e - LSB of address							;41c9	5e 	^ 
	inc hl					; hl points to MSB								;41ca	23 	# 
	ld d,(hl)				; de - address of routine						;41cb	56 	V 
	ex de,hl				; hl - address of routine						;41cc	eb 	. 
	jp (hl)					; execute routine 								;41cd	e9 	. 
ActionsPtrs:
	dw 	EnterTerminal		; run Terminal mode								;41ce	56 42 	B 
	dw 	FullHalfDuplex 		; switch beetween Half and Full Duplex			;41d0	dc 41 . A . 
	dw 	PrinterOnOff		; toggle Printer on/Off							;41d2	f7 41 	A 
	dw	SetDataBitCount		; set number of data bits						;41d4	38 42 	8 B 
	dw	SetStopBitCount		; set  number of stop bits						;41d6	47 42 	B 
	dw	SetParity 			; set Parity NONE/ODD/EVEN						;41d8	0b 42 	B 
	dw	SetAddLF2CR			; set if transmit LF after CR char 				;41da	01 42  	. B : 


FullHalfDuplex:
	ld a,(DUPLEX)			; current value of Full/Half duplex				;41dc	3a e0 80	. 
	or a					; is it now 0 									;41df	b7 	. 
	ld a,1					; 1 = Half duplex								;41e0	3e 01 	> . 
	ld hl,TxtHalf			; hl - 'HALF' text								;41e2	21 11 40 	! . @ 
	jr z,.setDuplex			; if 0 -> this will be Half Duplex				;41e5	28 04 	( . 
	xor a					; 0 = Full Duplex								;41e7	af 	. 
	ld hl,TxtFull			; hl - 'FULL' text								;41e8	21 0d 40 	! . @ 
.setDuplex:
	ld (DUPLEX),a			; store new value 								;41eb	32 e0 80 	2 . . 
	ld de,ScrDUPLEX			; dst - Offscreen data							;41ee	11 00 80 	. . . 
	ld bc,4					; 4 chars to copy								;41f1	01 04 00 	. . . 
	ldir					; copy 'HALF' or FULL to offscreen area			;41f4	ed b0 	. . 
	ret						; ------------ End of Proc ----------------		;41f6	c9 	. 

PrinterOnOff:
	ld hl,PRINTER			; Printer on/Off variable 						;41f7	21 df 80 	! . . 
	ld de,ScrPrinter		; destination where to print ON or OFF			;41fa	11 19 80 	. . . 
	call FlipOnOff			; flip value and print offscreen				;41fd	cd 21 42 	. ! B 
	ret						; ------------ End of Proc ----------------		;4200	c9 	. 

SetAddLF2CR
	ld hl,APPENDLF			; Add LF to CR variabale						;4201	21 e1 80 	! . . 
	ld de,ScrAppendLF		; destination where to print ON or OFF			;4204	11 79 80 	. y . 
	call FlipOnOff			; flip value and print offscreen				;4207	cd 21 42 	. ! B 
	ret						; ------------ End of Proc ----------------		;420a	c9 	. 

SetParity
	ld a,(ScrParity)		; char of Parity in offscreen buffer			;420b	3a 61 80 	: a . 
	cp 'N'					; is current parity = NONE						;420e	fe 4e 	. N 
	ld c,'E'				; change to EVEN								;4210	0e 45 	. E 
	jr z,.setValue			; yes - set to EVEN ('E')						;4212	28 08 	( . 
	cp 'E'					; is current parity = EVEN						;4214	fe 45 	. E 
	ld c,'O'				; change to ODD ('O')							;4216	0e 4f 	. O 
	jr z,.setValue			; yes - set to ODD								;4218	28 02 	( . 
	ld c,'N'				; change to NONE 								;421a	0e 4e 	. N 
.setValue:
	ld a,c					; a - new Parity value							;421c	79 	y 
	ld (ScrParity),a		; store new value								;421d	32 61 80 	2 a . 
	ret						; ------------ End of Proc ----------------		;4220	c9 	. 

	
FlipOnOff:
	ld a,(hl)				; a - on/off value 								;4221	7e 	~ 
	or a					; is it 0 (off)?								;4222	b7 	. 
	ld a,1					; new Value = On								;4223	3e 01 	> . 
	jr z,.setValue			; was off?										;4225	28 01 	( . 
	xor a					; new value = Off								;4227	af 	. 
.setValue:
	ld (hl),a				; store new value								;4228	77 	w 
	ld hl,TxtOff			; hl - 'OFF' text								;4229	21 0a 40 	! . @ 
	or a					; is new value = 0 (Off)						;422c	b7 	. 
	jr z,.print				; yes - print OFF								;422d	28 03 	( . 
	ld hl,TxtOn				; hl - 'ON ' text								;422f	21 07 40 	! . @ 
.print:
	ld bc,3					; 3 chars of text								;4232	01 03 00 	. . . 
	ldir					; display offscreen								;4235	ed b0 	. . 
	ret						; ----------- End of Proc -----------------		;4237	c9 	. 

SetDataBitCount
	ld a,(ScrDataBits)		; a - current data bits count					;4238	3a 31 80 	: 1 . 
	cp '7'					; is it 7 bits?									;423b	fe 37 	. 7 
	ld a,'8'				; change it to 8 bits							;423d	3e 38 	> 8 
	jr z,.setValue			; yes - change it to 8 bits						;423f	28 02 	( . 
	ld a,'7'				; change it to 7 bits							;4241	3e 37 	> 7 
.setValue:
	ld (ScrDataBits),a		; store new value								;4243	32 31 80 	2 1 . 
	ret						; ----------- End of Proc -----------------		;4246	c9 	. 

SetStopBitCount
	ld a,(ScrStopBits)		; a - current stop bits count					;4247	3a 49 80 	: I . 
	cp '1'					; is it 1 stop bit?								;424a	fe 31 	. 1 
	ld a,'2'				; change it to 2 stop bits						;424c	3e 32 	> 2 
	jr z,ssb2				; yes - change it to '2'						;424e	28 02 	( . 
	ld a,'1'				; change it to 1 stop bit						;4250	3e 31 	> 1 
ssb2:
	ld (ScrStopBits),a		; store new value								;4252	32 49 80 	2 I . 
	ret						; ----------- End of Proc -----------------		;4255	c9 	. 

EnterTerminal:
	call ClearScreen		; clear screen 									;4256	cd 56 43 	. V C 
TerminalLoop:
	call RSReadBit			; test if start bit found						;4259	cd 1d 43 	. . C 
	jr nz,.userInput		; no - skip reading RS byte						;425c	20 0e 	  . 
	call RSReadByte			; a - byte from serial							;425e	cd 8f 42 	. . B 
	call PrintChrSafe		; print received char							;4261	cd 6e 43 	. n C 
	ld c,a					; save received char							;4264	4f 	O 
	ld a,(PRINTER)			; a - printer ON/Off settings					;4265	3a df 80 	: . . 
	or a					; is printer ON?								;4268	b7 	. 
	call nz,LPrintChr		; yes - send char to printer					;4269	c4 53 44 	. S D 
.userInput:
	call GetKeyPress		; get pressed key								;426c	cd 66 44 	. f D 
	or a					; any key pressed?								;426f	b7 	. 
	jr z,TerminalLoop		; no - try read next char from serial			;4270	28 e7 	( . 
	cp $65					; pressed SHIFT+X ?								;4272	fe 65 	. e 
	ret z					; yes - return to Menu Screen					;4274	c8 	. 
	push af					; save af (pressed char)						;4275	f5 	. 
	call RSWriteByte		; write char to Serial							;4276	cd c6 42 	. . B 
	pop af					; restire af (char)								;4279	f1 	. 
	ld c,a					; c - char sent									;427a	4f 	O 
	ld a,(DUPLEX)			; a - duplex settings							;427b	3a e0 80 	: . . 
	or a					; is it Full Duplex?							;427e	b7 	. 
	ld a,c					; a - char sent									;427f	79 	y 
	jr z,TerminalLoop		; yes, when Full Duplex then start over			;4280	28 d7 	( . 
	call PrintChrSafe		; display char on screen						;4282	cd 6e 43 	. n C 
	ld c,a					; save char into c								;4285	4f 	O 
	ld a,(PRINTER)			; printer settings								;4286	3a df 80 	: . . 
	or a					; is PRINTER ON?								;4289	b7 	. 
	call nz,LPrintChr		; yes - send char to printer					;428a	c4 53 44 	. S D 
	jr TerminalLoop			; start over									;428d	18 ca 	. . 


; Read byte from serial input 
; OUT: a - byte
RSReadByte:
	call DelayHalfBit		; delay 1611 us (halfbit at 300 baud)			;428f	cd 2e 43 	. . C 
	call DelayFullBit		; delay 3230 us (full bit at 300 baud)			;4292	cd 23 43 	. # C 
	ld a,(ScrDataBits)		; a - number of data bits (ASCII char)			;4295	3a 31 80 	: 1 . 
	sub '0'					; a - number of data bits						;4298	d6 30 	. 0 
	ld e,a					; e - number of data bits						;429a	5f 	_ 
	ld b,8					; b - 8 bits to read (including stop)			;429b	06 08 	. . 
	ld c,0					; c - shift register							;429d	0e 00 	. . 
.next:
	ld a,b					; a - bits to read								;429f	78 	x 
	cp 1					; 1 left? (only stop bit to read)				;42a0	fe 01 	. . 
	jr nz,.readDataBit		; no - read data bit							;42a2	20 07 	  . 
	ld a,e					; a - configured number of data bits			;42a4	7b 	{ 
	cp 8					; is it 8 bits?									;42a5	fe 08 	. . 
	jr z,.nextBit			; yes - read 1 more bit of data					;42a7	28 0e 	( . 
	jr .parityBit			; no - read parity or stop bit					;42a9	18 0e 	. . 
.readDataBit:
	ld a,(RSINPUT)			; data bit on bit7								;42ab	3a 00 50 	: . P 
	and %10000000			; only 7 bit is valid							;42ae	e6 80 	. . 
	or c					; a - put it into shift register				;42b0	b1 	. 
	ld c,a					; store back into c								;42b1	4f 	O 
	srl c					; shift right c by 1 bit						;42b2	cb 39 	. 9 
	call DelayFullBit		; delay 3230 us (full bit @ 300 baud)			;42b4	cd 23 43 	. # C 
.nextBit:
	djnz .next				; read all 7 or 8 bits							;42b7	10 e6 	. . 
.parityBit:
	call DelayHalfBit2		; delay 1564 us (almost half bit)				;42b9	cd 3a 43 	. : C 
	ld a,(ScrParity)		; a - current Parity settings					;42bc	3a 61 80 	: a . 
	cp 'N'					; is it NONE? (skip parity)						;42bf	fe 4e 	. N 
	call nz,DelayFullBit	; delay 1 more bit (parity ODD/EVEN)			;42c1	c4 23 43 	. # C 
	ld a,c					; a - byte from serial completed				;42c4	79 	y 
	ret						; -------------- End of Proc ----------			;42c5	c9 	. 



RSWriteByte:
	push af					; save af										;42c6	f5 	. 
	ld a,$ff				; all bits set to 1								;42c7	3e ff 	> . 
	ld (RSOUTPUT),a			; start bit										;42c9	32 00 58 	2 . X 
	call DelayFullBit		; delay 3230 us (full bit @ 300 baud)			;42cc	cd 23 43 	. # C 
	ld a,(ScrDataBits)		; a - number of data bits as ASCII				;42cf	3a 31 80 	: 1 . 
	sub '0'					; a - number of data bits (7 or 8)				;42d2	d6 30 	. 0 
	ld b,a					; b - number of data bits						;42d4	47 	G 
	pop af					; a - char to send								;42d5	f1 	. 
	push af					; save af (char to send)						;42d6	f5 	. 
	ld c,a					; c - shift register							;42d7	4f 	O 
.nextBit:
	srl c					; CY gets bit 0									;42d8	cb 39 	. 9 
	ld a,0					; 0 if bit to send = 1							;42da	3e 00 	> . 
	jr c,.sendBit			; bit to send =1 ->  skip						;42dc	38 02 	8 . 
	ld a,$80				; $80 if bit to send = 0						;42de	3e 80 	> . 
.sendBit:
	ld (RSOUTPUT),a			; send bit to Serial							;42e0	32 00 58 	2 . X 
	call DelayFullBit		; delay 3230 us (full bit @ 300 baud)			;42e3	cd 23 43 	. # C 
	djnz .nextBit			; send 7 or 8 bits of data						;42e6	10 f0 	. . 
	pop af					; restora af (char to send) 					;42e8	f1 	. 
	ld c,a					; c - char sent									;42e9	4f 	O 
	ld a,(ScrParity)		; a - settings for Parity						;42ea	3a 61 80 	: a . 
	cp 'N'					; is it NONE?									;42ed	fe 4e 	. N 
	jr z,.sendStopBit		; yes - send stop bit							;42ef	28 1c 	( . 
; -- Parity
	ld a,c					; a - char 										;42f1	79 	y 
	or a					; set CPU Parity flag							;42f2	b7 	. 
	ld a,(ScrParity)		; a - Parity settings as ASCII					;42f3	3a 61 80 	: a . 
	jp po,.parityOdd		; jump if parity is odd							;42f6	e2 03 43 	. . C 
	cp 'E'					; settings is EVEN?								;42f9	fe 45 	. E 
.prepParity:
	ld a,$80				; parity bit = 0								;42fb	3e 80 	> . 
	jr z,.sendParityBit		; send 0 if settings and parity is EVEN 		;42fd	28 08 	( . 
	ld a,$00				; parity bit = 1								;42ff	3e 00 	> . 
	jr .sendParityBit		; send 1 coz settings is ODD 					;4301	18 04 	. . 
.parityOdd:
	cp 'O'					; settings is ODD?								;4303	fe 4f 	. O 
	jr .prepParity			; prepare and send parity bit					;4305	18 f4 	. . 
.sendParityBit:
	ld (RSOUTPUT),a			; send Parity bit								;4307	32 00 58 	2 . X 
	call DelayFullBit		; delay 3230 us (full bit @ 300 baud)			;430a	cd 23 43 	. # C 
.sendStopBit:
	ld a,(ScrStopBits)		; a - number of stop bits ASCII					;430d	3a 49 80 	: I . 
	sub '0'					; a - number of stop bits (1 or 2)				;4310	d6 30 	. 0 
	ld b,a					; b - counter for stop bits 					;4312	47 	G 
.loop:
	xor a					; a = 0 -> Serial bit = 1						;4313	af 	. 
	ld (RSOUTPUT),a			; send Stop bit									;4314	32 00 58 	2 . X 
	call DelayFullBit		; delay 3230 us (full bit @ 300 baud)			;4317	cd 23 43 	. # C 
	djnz .loop				; repeat if 2 stop bits							;431a	10 f7 	. . 
	ret						; ----------- End of Proc -------------			;431c	c9 	. 

; Read serial bit
; Z=1 if RS line is 
RSReadBit:
	ld a,(RSINPUT)		; read RS232 line into bit 7						;431d	3a 00 50 	: . P 
	bit 7,a				; is bit 7 set? (rs line is ???)					;4320	cb 7f 	.  
	ret					; ----------- End of Proc -------------				;4322	c9 	. 

DelayFullBit:
	push af				; save af											;4323	f5 	. 
	push bc				; save bc											;4324	c5 	. 
	call DelayHalfBit	; delay 1611 us (halbit)							;4325	cd 2e 43 	. . C 
	call DelayHalfBit	; delay 1611 us (halbit)							;4328	cd 2e 43 	. . C 
	pop bc				; restore bc										;432b	c1 	. 
	pop af				; restore af										;432c	f1 	. 
	ret					; ----------- End of Proc -------------				;432d	c9 	. 


; Delay 5767 ticks = 1611 us - half bit of 300 baud
DelayHalfBit:									;17 & from call instruction
	push bc				; save bc											;432e	c5 	. 			11
	ld a,35				; outer loop counter								;432f	3e 23 	> # 	7 
.loop1:
	ld b,11				; inner loop counter								;4331	06 0b 	. . 	7
.loop0:
	djnz .loop0			; wait 10*13T + 8T = 138 cycles						;4333	10 fe 	. . 	10*13 + 8 = 138
	dec a				; decrement outer loop counter						;4335	3d 	= 			4
	jr nz,.loop1		; wait 												;4336	20 f9 	  	7+34*(7+7+138+4+12)
	pop bc				; restore bc										;4338	c1 	. 			10
	ret					; ----------- End of Proc -------------				;4339	c9 	. 				10


; Delay 5600 ticks = 1564 us - litt;e less than half bit of 300 baud
DelayHalfBit2:
	call DelayHalfBit	; delay 1611 us (halbit)							;433a	cd 2e 43 	. . C 
	push bc				; save bc											;433d	c5 	. 
	ld a,34				; outer loop counter								;433e	3e 22 	> " 
	jr DelayHalfBit.loop1	; continue delay								;4340	18 ef 	. . 


	push af			;4342	f5 	. 
	push bc			;4343	c5 	. 
	ld bc,04fffh		;4344	01 ff 4f 	. . O 
	call 00060h		;4347	cd 60 00 	. ` . 
	pop bc			;434a	c1 	. 
	pop af			;434b	f1 	. 
	ret			;434c	c9 	. 

;******************************************************************
; Display null terminated string on Screen
; IN: hl - null terminated string
;------------------------------------------------------------------ 
PrintStr:
	ld a,(hl)				; a - char to display or 0						;434d	7e 	~ 
	or a					; is it o? (end of string)						;434e	b7 	. 
	ret z					; yes ---------- End of proc --------------		;434f	c8 	. 
	call PrintChrSafe		; print char preserving all registers			;4350	cd 6e 43 	. n C 
	inc hl					; address of next char to display or 0			;4353	23 	# 
	jr PrintStr				; continue with all chars						;4354	18 f7 	. . 


; -- Print $0c special char
ClearScreen:
; -- set cursor at 0,0 
	ld hl,SCREEN			; screen address for 1st char in 1st line 		;4356	21 00 70 	! . p 
	ld (CURSORADR),hl		; set cursor address							;4359	22 e5 80 	" . . 
; -- clear screen (fill with char $60 - inverted space)
	ld de,SCREEN+1			; dst - 2nd char of 1st line 					;435c	11 01 70 	. . p 
	ld bc,511				; 511 bytes to fill								;435f	01 ff 01 	. . . 
	ld (hl),$60				; set fill char									;4362	36 60 	6 ` 
	ldir					; fill screen with given char					;4364	ed b0 	. . 
; -- reset Sound and Gfx
	xor a					; 0 - GfxMode=0,CSS=0, Sound=off				;4366	af 	. 
	ld (CURSORCOL),a		; cursor in line (column)						;4367	32 e4 80 	2 . . 
	ld (VZLATCH),a			; GfxMode=0,CSS=0, Sound=off					;436a	32 00 68 	2 . h 
	ret						; ------------ End of Proc ----------------		;436d	c9 	. 


;******************************************************************
; Display char on Screen with preserving all registers
; IN: a - char to display (including special chars)
;------------------------------------------------------------------ 
PrintChrSafe:
	push af					; save af										;436e	f5 	. 
	push hl					; save hl										;436f	e5 	. 
	push bc					; save bc										;4370	c5 	. 
	push de					; save de										;4371	d5 	. 
	call PrintChr			; print char									;4372	cd 7a 43 	. z C 
	pop de					; restore de									;4375	d1 	. 
	pop bc					; restore bc									;4376	c1 	. 
	pop hl					; restore hl									;4377	e1 	. 
	pop af					; restore af									;4378	f1 	. 
	ret						; ------------ End of Proc ----------------		;4379	c9 	. 


;******************************************************************
; Display char on Screen 
; IN: a - char to display (including special chars)
;------------------------------------------------------------------ 
PrintChr:
	ld de,(CURSORADR)		; de - cursor address							;437a	ed 5b e5 80 	. [ . . 
	cp $c					; is it CLS char?								;437e	fe 0c 	. . 
	jr z,ClearScreen		; yes - clear screen							;4380	28 d4 	( . 
	cp $d					; is it CR char?								;4382	fe 0d 	. . 
	jr z,NewLine			; yes - NextLine								;4384	28 7e 	( ~ 
	cp $8					; is it $8 (move left) char?					;4386	fe 08 	. . 
	jr z,MoveCrsLeft		; yes - move cursor left						;4388	28 35 	( 5 
	cp $9					; is it $9 (move right) char?					;438a	fe 09 	. . 
	jr z,MoveCrsRight		; yes - move cursor right						;438c	28 16 	( . 
	cp $a					; is it $a (LineFeed) char						;438e	fe 0a 	. . 
	jr z,LineFeed			; yes - simulate line feed						;4390	28 4a 	( J 
	cp $7					; is it $7 (Bell) char?							;4392	fe 07 	. . 
	jp z,PlayBeep			; yes, play sound								;4394	ca 50 34 	. P 4 
	bit 7,a					; is it char > 127? 							;4397	cb 7f 	.  
	jr nz,.toVidMem			; yes - just put into screen memory				;4399	20 08 	  . 
	cp ' '					; is it < ' ' (other special char) ?			;439b	fe 20 	.   
	ret m					; yes - ignore it -------------------------		;439d	f8 	. 
	call ConvToUpper		; convert to upper case letter					;439e	cd 5d 44 	. ] D 
	set 6,a					; convert to screen code						;43a1	cb f7 	. . 
.toVidMem:
	ld (de),a				; put char into video memory and move cursor	;43a3	12 	. 
MoveCrsRight:
	inc de					; de - cursor address + 1						;43a4	13 	. 
	ld (CURSORADR),de		; set new cursor address						;43a5	ed 53 e5 80 	. S . . 
	ld a,(CURSORCOL)		; a - cursor in line							;43a9	3a e4 80 	: . . 
	inc a					; add 1 (move right)							;43ac	3c 	< 
	ld (CURSORCOL),a		; set new cursor in line						;43ad	32 e4 80 	2 . . 
	cp 32					; fall end of line?								;43b0	fe 20 	.   
	ret m					; no - ----------- End of Proc ------------		;43b2	f8 	. 
	call ForceNewLine		; add new line (regarding of settings)			;43b3	cd f3 43 	. . C 
	ld a,(PRINTER)			; a - Printer settings							;43b6	3a df 80 	: . . 
	or a					; is Printer ON?								;43b9	b7 	. 
	ret z					; no - ----------- End of Proc ------------		;43ba	c8 	. 
	call LPrintCR			; send CR to printer							;43bb	cd 49 44 	. I D 
	ret						; --------------- End of Procc ------------		;43be	c9 	. 

; print special char $8  (Left)
MoveCrsLeft:
	ld a,(CURSORCOL)		; a - cursor in line position					;43bf	3a e4 80 	: . . 
	or a					; is it 0 (start of line)?						;43c2	b7 	. 
	jr z,.moveToPrev		; yes - ;43c3	28 0a 	( . 
	dec a					; move 1 char left (decrement column)			;43c5	3d 	= 
.update:
	ld (CURSORCOL),a		; set new cursor in line index					;43c6	32 e4 80 	2 . . 
	dec de					; decrement cursor address						;43c9	1b 	. 
	ld (CURSORADR),de		; set new cursor address						;43ca	ed 53 e5 80 	. S . . 
	ret						; ----------- End of Proc -----------------		;43ce	c9 	. 

; -- cursor at start of line - try move to the end of previous line
.moveToPrev:
	push hl					; save hl										;43cf	e5 	. 
	ld hl,SCREEN			; hl - start of Screen							;43d0	21 00 70 	! . p 
	or a					; clear carry flag								;43d3	b7 	. 
	sbc hl,de				; if 0 - cursor is at start of 1st line 		;43d4	ed 52 	. R 
	pop hl					; restore hl									;43d6	e1 	. 
	ret z					; cannot move left - --- end of Proc ------		;43d7	c8 	. 
	ld a,31					; a - cursor at end of line						;43d8	3e 1f 	> . 
	jr .update				; update new cursor position 					;43da	18 ea 	. . 


LineFeed:
	ld a,(CURSORCOL)		; a - cursor in line index						;43dc	3a e4 80 	: . . 
	ld c,a					; c - cursor in line							;43df	4f 	O 
	ld b,0					; bc - cursor in line							;43e0	06 00 	. . 
	push bc					; save bc 										;43e2	c5 	. 
	call ForceNewLine		; print NewLine with LF (regardless settings)	;43e3	cd f3 43 	. . C 
	pop bc					; restore bc (cursor in line)					;43e6	c1 	. 
	ex de,hl				; hl - cursor address							;43e7	eb 	. 
	add hl,bc				; add cursor in line							;43e8	09 	. 
	ex de,hl				; move back to de								;43e9	eb 	. 
	ld (CURSORADR),de		; store new cursor address						;43ea	ed 53 e5 80 	. S . . 
	ld a,c					; a - cursor in line index						;43ee	79 	y 
	ld (CURSORCOL),a		; store as new value							;43ef	32 e4 80 	2 . . 
	ret						; ---------- End of Proc ----------------------	;43f2	c9 	. 
ForceNewLine:
	ld a,(APPENDLF)			; a - ADD LF TO CR settings						;43f3	3a e1 80 	: . . 
	push af					; save af (settings)							;43f6	f5 	. 
	ld a,1					; set ADD LF active								;43f7	3e 01 	> . 
	ld (APPENDLF),a			; store as current value						;43f9	32 e1 80 	2 . . 
	call NewLine			; add new line									;43fc	cd 04 44 	. . D 
	pop af					; restore af (settings)							;43ff	f1 	. 
	ld (APPENDLF),a			; restore previous Add LF setting				;4400	32 e1 80 	2 . . 
	ret						; ---------- End of Proc ----------------------	;4403	c9 	. 

; print $d (CR) special character
NewLine:
	push hl					; save hl										;4404	e5 	. 
	ex de,hl				; hl - cursor address 							;4405	eb 	. 
	ld a,(CURSORCOL)		; a - cursor in line index						;4406	3a e4 80 	: . . 
	ld e,a					; e - cursor in line							;4409	5f 	_ 
	ld d,0					; de - cursor in line 							;440a	16 00 	. . 
	or a					; clear carry flag								;440c	b7 	. 
	sbc hl,de				; hl - start of current line					;440d	ed 52 	. R 
	ld a,(APPENDLF)			; a - Add LF to CR settings						;440f	3a e1 80 	: . . 
	or a					; is append set?								;4412	b7 	. 
	jr z,.skip				; no, skip adding 1 line						;4413	28 04 	( . 
	ld de,32				; 32 chars = 1 line								;4415	11 20 00 	.   . 
	add hl,de				; hl - start of next line						;4418	19 	. 
.skip:
	ex de,hl				; de - start of next line						;4419	eb 	. 
	ld hl,SCREEN+512		; hl - last byte of screen + 1					;441a	21 00 72 	! . r 
	or a					; clear carry flag								;441d	b7 	. 
	sbc hl,de				; if 0 - next line is outside of screent 		;441e	ed 52 	. R 
	jr z,ScrollScreenUp		; yes - sroll screen up							;4420	28 0a 	( . 

SetNewCursorPos:
	ld (CURSORADR),de		; set new cursor address						;4422	ed 53 e5 80 	. S . . 
	xor a					; column 0										;4426	af 	. 
	ld (CURSORCOL),a		; set new cursor in line						;4427	32 e4 80 	2 . . 
	pop hl					; restore hl									;442a	e1 	. 
	ret						; -------------- End of Proc ------------------	;442b	c9 	. 


ScrollScreenUp:
; -- move screen 1 line up
	ld hl,SCREEN+32		; src - 2nd line of screen							;442c	21 20 70 	!   p 
	ld de,SCREEN		; dst - 1st line of screen							;442f	11 00 70 	. . p 
	ld bc,480			; 32 * 15 lines to copy 							;4432	01 e0 01 	. . . 
	ldir				; move screen up 1 line								;4435	ed b0 	. . 

	ld hl,SCREEN+480	; src - last line of screen 						;4437	21 e0 71 	! . q 
	ld de,SCREEN+480+1	; dst - 2nd char of last line						;443a	11 e1 71 	. . q 
	ld bc,31			; 31 chars to fill									;443d	01 1f 00 	. . . 
	ld (hl),$60			; store "'" char									;4440	36 60 	6 ` 
	ldir				; fill last line 									;4442	ed b0 	. . 
	ld de,SCREEN+480	; last line of screen								;4444	11 e0 71 	. . q 
	jr SetNewCursorPos	; update cursor position							;4447	18 d9 	. . 

LPrintCR:
	call GetPrtStatus	; check Printer status 								;4449	cd c4 05 	. . . 
	bit 0,a				; is ready?											;444c	cb 47 	. G 
	ret nz				; no - return --------------------					;444e	c0 	. 
	call SendCRToPrt	; send CR/LF to Printer								;444f	cd e2 3a 	. . : 
	ret					; --------- End of Proc -----------					;4452	c9 	. 

; Send char to Printer
LPrintChr:
	call GetPrtStatus	; check Printer status 								;4453	cd c4 05 	. . . 
	bit 0,a				; is ready?											;4456	cb 47 	. G 
	ret nz				; no - return --------------------					;4458	c0 	. 
	ld a,c				; a - char to send to printer						;4459	79 	y 
	jp SendToPrinter	; send char to printer via system 					;445a	c3 8d 05 	. . . 



ConvToUpper:
	cp 'a'				; is it >= 'a'?										;445d	fe 61 	. a 
	ret c				; no ----------------------------------------------	;445f	d8 	. 
	cp 'z'+1			; is it <= 'z'										;4460	fe 7b 	. { 
	ret nc				; no ----------------------------------------------	;4462	d0 	. 
	and $5f				; convert to upper case								;4463	e6 5f 	. _ 
	ret					; ------------ End of Proc ------------------------	;4465	c9 	. 

; Keyboard Skan
; /---------------------------------------------------------------------\
; |                         ADRES   |   D5  D4      D3  D2      D1  D0  |
; |---------|-----------------------------------------------------------|
KEYS_ROW_0:         equ     68FEh   ;   R   Q       E           W   T   |
KEYS_ROW_1:         equ     68FDh   ;   F   A       D   CTRL    S   G   |
KEYS_ROW_2:         equ     68FBh   ;   V   Z       C   SHIFT   X   B   |
KEYS_ROW_3:         equ     68F7h   ;   4   1       3           2   5   |
KEYS_ROW_4:         equ     68EFh   ;   M   SPACE   ,           .   N   |
KEYS_ROW_5:         equ     68DFh   ;   7   0       8   -       9   6   |
KEYS_ROW_6:         equ     68BFh   ;   U   P       I   RETURN  O   Y   |
KEYS_ROW_7:         equ     687Fh   ;   J   ;       K   :       L   H   |
; |---------|-----------------------------------------------------------|    

GetKeyPress:
	ld hl,KEYS_ROW_0		; activate row 0								;4466	21 fe 68 	! . h 
	ld c,8					; 8 rows to scan								;4469	0e 08 	. . 
.nextRow:
	ld b,6					; 6 column to scan								;446b	06 06 	. . 
	ld a,(hl)				; read row 0 bits								;446d	7e 	~ 
	or %000100				; ignore D2 (CTRL,SHIFT, etc)					;446e	f6 04 	. . 
.nextCol:
	rra						; bit 0 to CY  									;4470	1f 	. 
	jr nc,DecodeKey			; key pressed 									;4471	30 59 	0 Y 
	djnz .nextCol			; check next bit/column							;4473	10 fb 	. . 
; -- row tested - check next row
	rlc l					; set next row active							;4475	cb 05 	. . 
	dec c					; all rows checked?								;4477	0d 	. 
	jr nz,.nextRow			; no - chceck next row							;4478	20 f1 	  . 
; -- check ignored D2 column - key '-'
	ld b,4					; predefined for column D2						;447a	06 04 	. . 
	ld hl,KEYS_ROW_5		; row with '-' key								;447c	21 df 68 	! . h 
	ld a,(hl)				; read keyboard									;447f	7e 	~ 
	bit 2,a					; is '-' pressed?								;4480	cb 57 	. W 
	jr z,MinusPressed		; yes - set row (c=3) and decode				;4482	28 3e 	( > 
; -- check ignored D2 column - key RETURN
	rlc l					; set next active row (with RETURN)				;4484	cb 05 	. . 
	ld a,(hl)				; read keyboard									;4486	7e 	~ 
	bit 2,a					; is RETURN pressed?							;4487	cb 57 	. W 
	jr z,RETURNPressed		; yes - set row (c=2) and decode				;4489	28 3b 	( ; 
; -- check ignored D2 column - key ':'
	rlc l					; set next active row (with ':')				;448b	cb 05 	. . 
	ld a,(hl)				; read keyboard									;448d	7e 	~ 
	bit 2,a					; is ':' pressed?								;448e	cb 57 	. W 
	jr z,ColonPressed		; yes - set row (c=1) and decode				;4490	28 38 	( 8 
; -- skip checking D2 column for row 0
	rlc l					; set next active row 0							;4492	cb 05 	. . 
; -- check ignored D2 column - key CTRL
	rlc l					; set next active row (with CTRL)				;4494	cb 05 	. . 
	ld a,(hl)				; read keyboard									;4496	7e 	~ 
	bit 2,a					; is CTRL pressed?								;4497	cb 57 	. W 
	jr z,.CTRLPressed		; yes - set CTRL pressed						;4499	28 11 	( . 
; -- check ignored D2 column - key CTRL
	rlc l					; set next active row (with SHIFT)				;449b	cb 05 	. . 
	ld a,(hl)				; read keyboard									;449d	7e 	~ 
	bit 2,a					; is SHIFT pressed?								;449e	cb 57 	. W 
	jr z,.SHIFTPressed		; yes -set SHIFT pressed						;44a0	28 11 	( . 
; -- no key pressed
	ld a,-1					; no key										;44a2	3e ff 	> . 
	ld (LASTKEY),a			; save as last key pressed						;44a4	32 e2 80 	2 . . 
	xor a					; no special keys pressed						;44a7	af 	. 
	ld (KEYFLAGS),a			; clear key flags								;44a8	32 e3 80 	2 . . 
	ret						; -------- End of Proc (result 0) -				;44ab	c9 	. 

; CTRL pressed
.CTRLPressed:
	ld a,(KEYFLAGS)			; a - current key flags							;44ac	3a e3 80 	: . . 
	set 2,a					; set bit 2 - CTRL key active					;44af	cb d7 	. . 
	jr .updateFlags			; set CTRL in KEYFLAGS							;44b1	18 05 	. . 
; SHIFT pressed
.SHIFTPressed:
	ld a,(KEYFLAGS)			; a - current key flags							;44b3	3a e3 80 	: . . 
	set 1,a					; set bit 1 - SHIFT key active					;44b6	cb cf 	. . 
.updateFlags:
	ld (KEYFLAGS),a			; store new flags value							;44b8	32 e3 80 	2 . . 
	ld a,-1					; no key										;44bb	3e ff 	> . 
	ld (LASTKEY),a			; save -1 as last key pressed					;44bd	32 e2 80 	2 . . 
ExitNoKey:
	xor a					; 0 - no key pressed							;44c0	af 	. 
	ret						; -------- End of Proc (result 0) -				;44c1	c9 	. 

; -- key '-' pressed
MinusPressed:
	ld c,3					; predefined for row 5							;44c2	0e 03 	. . 
	jr DecodeKey			; decode key to ASCII							;44c4	18 06 	. . 
; -- RETURN pressed
RETURNPressed:
	ld c,2					; predefined for row 6							;44c6	0e 02 	. . 
	jr DecodeKey			; decode key to ASCII							;44c8	18 02 	. . 
; -- key ':' pressed
ColonPressed:
	ld c,1					; predefined for row 7							;44ca	0e 01 	. . 
DecodeKey:
	ld hl,KeysTable			; hl - address of key to ASCII map table		;44cc	21 06 45 	! . E 
	ld e,0					; extra offset in KeyTable = 0					;44cf	1e 00 	. . 
	ld a,(KEYFLAGS)			; a - active Key Flags							;44d1	3a e3 80 	: . . 
	bit 2,a					; is CTRL pressed?								;44d4	cb 57 	. W 
	jr z,.checkShift		; no - check SHIFT key							;44d6	28 04 	( . 
	ld e,$60				; add $60 offset								;44d8	1e 60 	. ` 
	jr LookupKey			; cals final offset and get char from map		;44da	18 06 	. . 
.checkShift:
	bit 1,a					; is SHIFT pressed								;44dc	cb 4f 	. O 
	jr z,LookupKey			; no - skip adding offset						;44de	28 02 	( . 
	ld e,$30				; add $30 offset								;44e0	1e 30 	. 0 
LookupKey:
	ld a,8					; calculate row as 8 minus row					;44e2	3e 08 	> . 
	sub c					; a - row number								;44e4	91 	. 
	ld c,a					; store back to c								;44e5	4f 	O 
	ld a,6					; calculate column as 6 - column				;44e6	3e 06 	> . 
	sub b					; a - column number								;44e8	90 	. 
	ld b,a					; store back to b								;44e9	47 	G 
	call CalcIndex			; calculate index from b and c					;44ea	cd fb 44 	. . D 
	add a,e					; add offset for SHIFT and/or CTRL				;44ed	83 	. 
	ld b,0					; MSB of index to lookup table					;44ee	06 00 	. . 
	ld c,a					; bc - index									;44f0	4f 	O 
	add hl,bc				; hl - address in table							;44f1	09 	. 
	ld a,(hl)				; a - ASCII key									;44f2	7e 	~ 
	ld hl,LASTKEY			; hl - variable LASTKEY							;44f3	21 e2 80 	! . . 
	cp (hl)					; the same as last one?							;44f6	be 	. 
	jr z,ExitNoKey			; yes - return no key pressed					;44f7	28 c7 	( . 
	ld (hl),a				; store key as last pressed						;44f9	77 	w 
	ret						; --------- End of Proc -------					;44fa	c9 	. 

CalcIndex:
	xor a					; a - result									;44fb	af 	. 
	cp c					; is row = 0?									;44fc	b9 	. 
	jr z,l4504h				; yes - just add columns						;44fd	28 05 	( . 
.add6perCol:
	add a,6					; add 6 columns per row							;44ff	c6 06 	. . 
	dec c					; all coumns counted?							;4501	0d 	. 
	jr nz,.add6perCol		; no - keep adding								;4502	20 fb 	  . 
l4504h:
	add a,b					; add column									;4504	80 	. 
	ret						; -------- End of Proc -------- 				;4505	c9 	. 

KeysTable:
	db	'T','W',' ','E','Q','R' 						; row 0				;4506	54 57 20 45 51 52 	R 
	db 	'G','S',' ','D','A','F'							; row 1				;450c	47 53 20 44 41 46 	F 
	db	'B','X',' ','C','Z','V'							; row 2				;4512	42 58 20 43 5a 56 	V 
	db	'5','2',' ','3','1','4'							; row 3				;4518	35 32 20 33 31 34 	1 4  
	db	'N','.',' ',',',' ','M' 						; row 4				;451e	4e 2e 20 2c 20 4d 	  M 
	db 	'6','9','-','8','0','7'							; row 5				;4524	36 39 2d 38 30 37 	7 
	db	'Y','O',$0d,'I','P','U' 						; row 6				;452a	59 4f 0d 49 50 55 	U 
	db	'H','L',':','K',';','J' 						; row 7				;4530	48 4c 3a 4b 3b 4a 	J 
; -- with SHIFT
	db	0,0,0,0,0,0										; row 0				;4536	00 00 00 00 00 00 	. 
	db	0,0,0,0,0,0										; row 1				;453c	00 00 00 00 00 00 	. 
	db	0,$65,0,0,0,0									; row 2 (SHIFT+X)	;4542	00 65 00 00 00 00 	. 
	db	'%','"',' ','#','!','$' 						; row 3				;4548	25 22 20 23 21 24  	! $  
	db	'^','>',$00,'<',$00,$5c 						; row 4				;454e	5e 3e 00 3c 00 5c 	\ 
	db	'&',')','=','(','@',$27							; row 5				;4554	26 29 3d 28 40 27 	' 
	db 	$00,'[',$0d,$00,']',$00							; row 6				;455a	00 5b 0d 00 5d 00 	. 
	db	$00,'?','*','/','+',$00							; row 7				;4560	00 3f 2a 2f 2b 00 	. 
; -- with CTRL
	db	$14,$17,$00,$05,$11,$12 						; row 0				;4566	14 17 00 05 11 12 	. . . 
	db	$07,$13,$00,$00,$01,$06							; row 1				;456c	07 13 00 00 01 06  	. . . 
	db	$02,$16,$00,$03,$1a,$16 						; row 2				;4572	02 16 00 03 1a 16  	. . 
	db 	$00,$00,$00,$00,$00,$00							; row 3				;4578	00 00 00 00 00 00 	. 
	db	$0e,$00,$00,$00,$00,$0d 						; row 4				;457e	0e 00 00 00 00 0d 	. 
	db 	$00,$00,$00,$00,$00,$00							; row 5				;4584	00 00 00 00 00 00 	. 
	db	$19,$0f,$00,$09,$10,$15 						; row 6				;458a	19 0f 00 09 10 15 	. . 
	db	$08,$0c,$00,$0b,$00,$0a 						; row 7				;4590	08 0c 00 0b 00 0a 	. 

	BLOCK 618,$ff
