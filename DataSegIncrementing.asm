;
; SpellCOPE.asm
;
; Created: 9/12/2023 7:02:54 PM
; Author : Trey Vokoun
;

.include "m328Pdef.inc" ; tells what microcontroller we have and what instructions it takes

; Define the data segment
.dseg
data_segment: .db 0x3F,0x30,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x67,0x77,0x7C,0x39,0x5E,0x79,0x71

;>>>>>Begin Code Segment<<<<<
.cseg
.org 0


; put code here to configure I/O lines
; as output & connected to SN74HC595
sbi   DDRB,0	  ; PB0 is now output for ShiftRegister's SER 
sbi   DDRB,1      ; PB1 is now output for ShiftRegister's RCLK Input
sbi   DDRB,2      ; PB2 is now output for ShiftRegister's SRCLK Input

; start main program
start:
	; display a digit
	ldi R16, 0x3F ; load pattern to display  (3F = 0)
	rcall display ; call display subroutine
	rcall counter

	ldi XL, low(data_segment)   ; Load the low byte of the data segment address into XL
	;ldi XH, high(data_segment)  ; Load the high byte of the data segment address into XH

	ldi R18, 15                  ; Set the loop counter to 5 (number of data bytes)

	mainloop:
		ld R16, X+              ; Load data from the address pointed to by X into r16 which is the display
		; Do something with r16, e.g., store it in memory or perform calculations
		rcall display ; push the new pattern
		rcall counter

		;inc X                   ; Increment the X register to point to the next address

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
	ldi r30, low(count)	  	; r31:r30  <-- load a 16-bit value into counter register for outer loop
	ldi r31, high(count);
	d1:
		ldi   r29, 0xfb		    	; r29 <-- load a 8-bit value into counter register for inner loop
		d2:
			nop				; no operation
			dec   r29            		; r29 <-- r29 - 1
		brne  d2			; branch to d2 if result is not "0"
		sbiw r31:r30, 1			; r31:r30 <-- r31:r30 - 1
	brne d1				; branch to d1 if result is not "0"
ret				; return
