;====================================
; StopwatchLab2.asm
;
; Created: 9/12/2023 7:02:54 PM
; Authors: Trey Vokoun & Zach Ramsey
;====================================

.include "m328Pdef.inc" ; microcontroller-specific definitions

;>>>>>Begin Data Segment<<<<<
.dseg
.org 0x0100
Digit_Patterns: .byte 16	; Hex Digit Pattern Encoding

;>>>>>Begin Code Segment<<<<<
.cseg
.org 0

;==================| Configure I/O |=================
; Output to shiftreg SN74HC595
sbi DDRB,0	; Board O/P: PB0 -> ShiftReg I/P: SER
sbi DDRB,1	; Board O/P: PB1 -> ShiftReg I/P: RCLK
sbi DDRB,2	; Board O/P: PB2 -> ShiftReg I/P: SRCLK

; Input from pushbuttons
cbi DDRD,6	; Pushbutton A -> Board I/P: PD6
cbi DDRD,7	; Pushbutton B -> Board I/P: PD7


;========| Configure custom state register |=========
.def Ctrl_Reg = R19				; custom state values stored in R18

; state masks
.equ A_State = 0b00000001		; bit 0: button A was pressed   (0:None    | 1:Pressed)
.equ B_State = 0b00000010		; bit 1: button B was pressed   (0:None    | 1:Pressed)
.equ Incr_Mode = 0b00000100		; bit 2: incrementing mode		(0:1s      | 1:10s)
.equ Run_State = 0b00001000		; bit 3: incrementing state     (0:Stopped | 1:Running)
.equ Reset_State = 0b00010000	; bit 4: reset state            (0:None    | 1:Reset)
.equ Ovrflw = 0b00100000		; bit 5: overflow state         (0:None    | 1:Overflow)

;-----Usage-----
; Set State:
; sbr Ctrl_Reg, (state mask)

; Clear State:
; cbr Ctrl_Reg, (state mask)

; Skip next if bit is 0:
; sbrc Ctrl_Reg, (reg bit #)

; Skip next if bit is 1:
; sbrs Ctrl_Reg, (reg bit #)
;---------------


;=========| Load Values to Digit_Patterns |==========
ldi ZH, high(Digit_Patterns)	; Move pointer to front of Digit_Patterns
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


;===================| Main Loop |====================
sbr Ctrl_Reg, Reset_State	; Start in reset condition

start:
	sbrc Ctrl_Reg, 4		; if Reset_State is 1 -> call Count_Reset
	rcall Count_Reset

	sbrs Ctrl_Reg, 3		; If Run_State is 0/stopped -> Call Count_Stopped
	rcall Count_Stopped

	sbrc Ctrl_Reg, 3		; If Run_State is 1/Running -> Call Count_Running
	rcall Count_Running

	rjmp start				; continue loop


;============| Reset State Subroutine |==============
Count_Reset:
	ldi ZH, high(Digit_Patterns)	; Move pointer to front of Digit_Patterns
    ldi ZL, low(Digit_Patterns)
	ld R16, Z+						; load first digit to display
	rcall display
	ldi R18, 16						; set counter to 16
	cbr Ctrl_Reg, Reset_State		; Clear Reset_State
	ret


;===========| Running State Subroutine |=============
Count_Running:
	sbrs Ctrl_Reg, 2				; If Incr_Mode is 0 -> call one_delay subroutine
	rcall one_delay
	ld R16, Z+						; Load next digit in table
	rcall display					; Display it
	dec R18							; If R18 has not reached 0 -> Loop
	brne Count_Running
loop_count:
	ldi ZH, high(Digit_Patterns)	; Move pointer to front of Digit_Patterns
    ldi ZL, low(Digit_Patterns)
	ld R16, Z+						; load first digit to display
	rcall display
	ldi R18, 16						; set counter to 16
	rjmp Count_Running				; Loop


;===========| Stopped State Subroutine |=============
Count_Stopped:
	sbis PIND,6				; If A is pressed -> Jump to A_Pressed
	rjmp A_Pressed
	sbis PIND,7				; If B is pressed -> Jump to B_Pressed
	rjmp B_Pressed
	rjmp Count_Stopped		; Else -> Jump to Count_Stopped
A_Pressed:
	sbis PIND, 6			; If A is released -> Continue to A_Released
	rjmp A_Pressed
A_Released:
	sbr Ctrl_Reg, Run_State	; Set Run_State to 1
	ret						; Return
B_Pressed:
	sbis PIND, 7			; If B is released -> Continue to B_Released
	rjmp B_Pressed
B_Released:
	ldi R16, 0x7c			; Temp; just tells you that you pressed B
	rcall display
	ret						; Return


;===========| Incrementing Subroutines |=============

; 1 second delay w/ button release check
.equ count1 = 0x6969		; assign hex val for outer loop decrement (64000) TODO: dial these in to 1s
.equ count2 = 0x69			; assign hex val for inner loop decrement (250)
one_delay:
	ldi r26, low(count1)	; load count1 into outer loop counter (r27:r26)
	ldi r27, high(count1)
D1:
	ldi r25, count2			; load count2 into inner loop counter (r25)
D2:
	dec r25					; r25 <-- r25 - 1
	brne D2					; If r24 is not 0 -> branch to D2
	sbiw r27:r26, 1			; r27:r26 <-- r27:r26 - 1
	brne D1					; if r26:r25 is not 0 -> branch to D1 
	ret						; return


;============| Display Digit Subroutine |============
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
