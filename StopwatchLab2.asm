;
; StopwatchLab2.asm
;
; Created: 9/12/2023 7:02:54 PM
; Authors : Trey Vokoun, Zach Ramsey
;

.include "m328Pdef.inc" ; tells what microcontroller we have and what instructions it takes
.cseg
.org 0

; Hex Digit encoding
.equ hex0 = 0x3F	; Hex code for 0
.equ hex1 = 0x30	; Hex code for 1
.equ hex2 = 0x5B	; Hex code for 2
.equ hex3 = 0x4F	; Hex code for 3
.equ hex4 = 0x66	; Hex code for 4
.equ hex5 = 0x6D	; Hex code for 5
.equ hex6 = 0x7D	; Hex code for 6
.equ hex7 = 0x07	; Hex code for 7
.equ hex8 = 0x7F	; Hex code for 8
.equ hex9 = 0x67	; Hex code for 9
.equ hexa = 0x77	; Hex code for a
.equ hexb = 0x7C	; Hex code for b
.equ hexc = 0x39	; Hex code for c
.equ hexd = 0x5E	; Hex code for d
.equ hexe = 0x79	; Hex code for e
.equ hexf = 0x71	; Hex code for f


; Configure I/O lines as output to shiftreg SN74HC595
sbi DDRB,0			; Board O/P: PB0 -> ShiftReg I/P: SER
sbi DDRB,1			; Board O/P: PB1 -> ShiftReg I/P: RCLK
sbi DDRB,2			; Board O/P: PB2 -> ShiftReg I/P: SRCLK

; Configure I/O lines as input from pushbuttons
cbi DDRD,6			; Pushbutton A -> Board I/P: PD6
cbi DDRD,7			; Pushbutton B -> Board I/P: PD7


; begin main loop
start:
	ldi R16, hex0	; initially load 0 to display
 
	SBIS PIND,6		; Skip next instruction if Pin6 is set
 	ldi R16, hex7	; Load pattern if pushbutton A is pressed

	SBIS PIND,7		; Skip next instruction if PIN7 is set
	ldi R16, hexe	; Load pattern if pushbutton B is pressed

	rcall display	; call display subroutine
rjmp start


; subroutine for displaying digit
display:
	; backup used registers on stack
	push R16		; Push R16 to stack
	push R17		; Push R17 to stack
	in R17, SREG	; Input from SREG -> R17
	push R17		; Push R17 to stack
	ldi R17, 8		; loop --> test all 8 bits
loop:
	rol R16			; rotate left through Carry
	BRCS set_ser	; branch if Carry is set
	cbi PORTB,0		; clear SER (SER -> 0)
rjmp end
set_ser:
	sbi PORTB,0		; set SER (SER -> 1)
end:
	; generate SRCLK pulse
	sbi PORTB,2		; SRCLK on
	nop				; pause to help circuit catch up
	cbi PORTB,2     ; SRCLK off
	dec R17
	brne loop
	
	; generate RCLK pulse
	sbi PORTB,1     ; RCLK on
	nop				; pause to help circuit catch up
	cbi PORTB,1     ; RCLK off

	; restore registers from stack
	pop R17
	out SREG, R17
	pop R17
	pop R16
ret
