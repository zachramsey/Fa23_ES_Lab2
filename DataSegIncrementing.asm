;
; SpellCOPE.asm
;
; Created: 9/12/2023 7:02:54 PM
; Author : Trey Vokoun
;

.include "m328Pdef.inc" ; tells what microcontroller we have and what instructions it takes

; Define the data segment
.dseg
.org 0x0100
Digit_Patterns: .byte 16 ;reserve 16 bytes



;>>>>>Begin Code Segment<<<<<
.cseg
.org 0


; put code here to configure I/O lines
; as output & connected to SN74HC595
sbi   DDRB,0	  ; PB0 is now output for ShiftRegister's SER 
sbi   DDRB,1      ; PB1 is now output for ShiftRegister's RCLK Input
sbi   DDRB,2      ; PB2 is now output for ShiftRegister's SRCLK Input


;===================| Main Loop |====================
main:
	ldi ZH, high(Digit_Patterns)	; Move Z register 
    ldi ZL, low(Digit_Patterns)
	ldi R20, 0x3F	; "0" Pattern
	st Z+, R20
	ldi R20, 0x06	; "1" Pattern
	st Z+, R20
	ldi R20, 0x5B	; "2" Pattern
	st Z+, R20
	ldi R20, 0x4F	; "3" Pattern
	st Z+, R20
	ldi R20, 0x66	; "4" Pattern
	st Z+, R20
	ldi R20, 0x6D	; "5" Pattern
	st Z+, R20
	ldi R20, 0x7D	; "6" Pattern
	st Z+, R20
	ldi R20, 0x07	; "7" Pattern
	st Z+, R20
	ldi R20, 0x7F	; "8" Pattern
	st Z+, R20
	ldi R20, 0x67	; "9" Pattern
	st Z+, R20
	ldi R20, 0x77	; "A" Pattern
	st Z+, R20
	ldi R20, 0x7C	; "b" Pattern
	st Z+, R20
	ldi R20, 0x39	; "C" Pattern
	st Z+, R20
	ldi R20, 0x5E	; "d" Pattern
	st Z+, R20
	ldi R20, 0x79	; "E" Pattern
	st Z+, R20
	ldi R20, 0x71	; "F" Pattern
	st Z+, R20
	;sbr Ctrl_Reg, Reset_State	; set Reset_State initially
	ldi R20, 16					; 16 elements in digit pattern array

; start main program
start:
	; display a digit
	ldi R16, 0x3F ; load pattern to display  (3F = 0)
	rcall display ; call display subroutine
	rcall counter

	ldi ZL, low(Digit_Patterns)   ; Load the low byte of the data segment address into XL
	ldi ZH, high(Digit_Patterns)  ; Load the high byte of the data segment address into XH

	ldi R18, 16                  ; Set the loop counter to 5 (number of data bytes)
	
	ldi ZH, high(Digit_Patterns)	; Move Z register to beginning
    ldi ZL, low(Digit_Patterns)

	mainloop:
		ld R16, Z+              ; Load data from the address pointed to by X into r16 which is the display
		; Do something with r16, e.g., store it in memory or perform calculations
		rcall display ; push the new pattern
		rcall counter
		dec R18                 ; Decrement the loop counter
	brne mainloop               ; If the loop counter is not zero, repeat the loop

	; The loop will iterate through the data_segment, loading each byte into r17
	rcall spellcope ; just putting this here to test when it loops back
rjmp start


display:
	; backup used registers on stack
	push R16
	push R17
	in R17, SREG
	push R17
	ldi R17, 8 ; loop --> test all 8 bits
loop:
	rol R16 ; rotate left trough Carry
	BRCS set_ser_in_1 ; branch if Carry is set
	; put code here to set SER to 0
	cbi   PORTB,0     ; SER to 0
rjmp end
set_ser_in_1:
	; put code here to set SER to 1
	sbi   PORTB,0     ; SER to 1
end:
	; put code here to generate SRCLK pulse
	sbi   PORTB,2     ; SRCLK on
	nop               ; pause to help circuit catch up
	cbi   PORTB,2     ; SRCLK off

	dec R17
	brne loop
	; put code here to generate RCLK pulse
	sbi   PORTB,1     ; RCLK on
	nop               ; pause to help circuit catch up
	cbi   PORTB,1     ; RCLK off

	; restore registers from stack
	pop R17
	out SREG, R17
	pop R17
	pop R16
ret

spellcope:
	.equ count = 0x25a6			; assign a 16-bit value to symbol "count"
	rcall counter ; call counter function
	ldi R16, 0x39 ; load pattern C to display
	rcall display ; call display subroutine
	rcall counter ; call counter function

	ldi R16, 0x3F ; load pattern O to display
	rcall display ; call display subroutine
	rcall counter ; call counter function

	ldi R16, 0x73 ; load pattern P to display
	rcall display ; call display subroutine
	rcall counter ; call counter function

	ldi R16, 0x79 ; load pattern E to display
	rcall display ; call display subroutine
	rcall counter ; call counter function
ret

counter:
	ldi r26, low(count)	  	; r31:r30  <-- load a 16-bit value into counter register for outer loop
	ldi r27, high(count);
	d1:
		ldi   r29, 0xfb		    	; r29 <-- load a 8-bit value into counter register for inner loop
		d2:
			nop				; no operation
			dec   r29            		; r29 <-- r29 - 1
		brne  d2			; branch to d2 if result is not "0"
		sbiw r27:r26, 1			; r31:r30 <-- r31:r30 - 1
	brne d1				; branch to d1 if result is not "0"
ret				; return
