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
.def Disp_Queue = R16	; Data queue for next digit to be displayed
.def Disp_Decr = R17	; Count of remaining bits to be pushed from Disp_Queue; decrements from 8
.def Digit_Decr = R18	; Count of remaining digits; decrements from 16
.def Ctrl_Reg = R19		; Custom state register
.def Digit_Buff = R20	; Data buffer for loading to Digit_Patterns
.def Ten_Decr = R21		; Count of remaining calls to one_delay; decrements from 10

; Custom state register masks
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

ldi Digit_Buff, 0x3F	; "0" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x06	; "1" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x5B	; "2" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x4F	; "3" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x66	; "4" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x6D	; "5" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x7D	; "6" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x07	; "7" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x7F	; "8" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x67	; "9" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x77	; "A" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x7C	; "b" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x39	; "C" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x5E	; "d" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x79	; "E" Pattern
st Z+, Digit_Buff
ldi Digit_Buff, 0x71	; "F" Pattern
st Z+, Digit_Buff


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
	ld Disp_Queue, Z+				; Load first digit to display
	sbrc Ctrl_Reg, 2				; If Incr_Mode is 1 -> Set DP bit
	sbr Disp_Queue, 0b10000000
	rcall display
	ldi Digit_Decr, 16				; Digit_Decr <- 16
	cbr Ctrl_Reg, Reset_State		; Reset_State <- 0
	cbr Ctrl_Reg, Ovrflw			; Reset Overflow state
ret


;===========| Running State Subroutine |=============
; TODO: Implement overflow condition
Count_Running:
	sbrc Ctrl_Reg, 2				; If Incr_Mode is 1 -> call ten_delay subroutine
	rcall Ten_Delay
	rcall One_Delay					; Else -> call one_delay subroutine

	sbrs Ctrl_Reg, 3				; If Run_State is 0 -> return
	ret

	ld Disp_Queue, Z+				; Load next digit in table

	sbrc Ctrl_Reg, 2				; If Incr_Mode is 1 -> Set DP bit
	sbr Disp_Queue, 0b10000000

	rcall display					; Push to dispay

	dec Digit_Decr					; If Digit_Decr has not reached 0 -> Loop
	brne Count_Running
overflow:
	ldi Disp_Queue, 0x40            ;load dash into the queue
	sbrc Ctrl_Reg, 2				; If Incr_Mode is 1 -> Set DP bit
	sbr Disp_Queue, 0b10000000

	rcall display					; Push to display
	cbr Ctrl_Reg, Run_State         ; clear the bit in the state register for Run_State because we have overflow and thus have stopped.
	sbr Ctrl_Reg, Ovrflw			; Set overflow state
rjmp Count_Stopped


;===========| Stopped State Subroutine |=============
; TODO: Make overflow clearing implementation work (Re:Running State TODO) I think I solved this -Trey
;		Make increment mode toggle work
Count_Stopped:
	sbis PIND,6					; If A is pressed -> Jump to A_Pressed
	rjmp A_Pressed
	sbis PIND,7					; If B is pressed -> Jump to B_Pressed
	rjmp B_Pressed
	rjmp Count_Stopped			; Else -> Jump to Count_Stopped
A_Pressed:
	sbrc Ctrl_Reg, 5			; If Ovrflw is set -> Jump to Count_Stopped
	rjmp Count_Stopped
	sbis PIND, 6				; If A is released -> Continue to A_Released
	rjmp A_Pressed
A_Released:
	sbr Ctrl_Reg, Run_State		; Run_State <- 1
	ret
B_Pressed:
	sbr Ctrl_Reg, B_State		; B_State <- 1

	rcall one_delay				; Wait 1s for button release
	sbrs Ctrl_Reg, 1			; If B_State is 0 -> Jump to Reset_Count
	rjmp Reset_Count

	rcall one_delay				; Wait 1s for button release
	sbrs Ctrl_Reg, 1			; If B_State is 0 -> Jump to Tggl_Incr_Mode
	rjmp Tggl_Incr_Mode

B_Wait:
	rcall one_delay				; Wait 1s for button release
	sbrs Ctrl_Reg, 1			; If B_State is 0 -> Jump to Clr_Ovrflw
	rjmp Clr_Ovrflw
	rjmp B_Wait					; Else -> Loop to wait longer

Reset_Count:
	sbrc Ctrl_Reg, 5			; If Ovrflw is 1 -> Jump to Count_Stopped
	rjmp Count_Stopped
	sbr Ctrl_Reg, Reset_State	; Reset_State <- 1
	ret
Tggl_Incr_Mode:
	sbrc Ctrl_Reg, 5			; If Ovrflw is 1 -> Jump to Count_Stopped
	rjmp Count_Stopped

	ldi R22, Incr_Mode
	eor Ctrl_Reg, R22			; Switch Increment Mode

	ldi R22, 0x80
	ADD Disp_Queue, R22
	rcall display				; Push to dispay

	rjmp Count_Stopped
Clr_Ovrflw:
	sbrc Ctrl_Reg, 5			; If Ovrflw is 1 -> (Reset_State <- 1)
	sbr Ctrl_Reg, Reset_State
	cbr Ctrl_Reg, Ovrflw		; Ovrflw <- 0
	ret


;===========| Incrementing Subroutines |=============

; calls one_delay 10 times (TODO: needs to early return if one_delay early returns)
Ten_Delay:
	ldi Ten_Decr, 10	; Ten_Decr <- 10
Next_Second:
	rcall One_Delay		; Call the one delay and loop through 10 times to get 10 sec.
	dec Ten_Decr		; r20 <- r20 - 1
	brne Next_Second	; If r27 is not 0 -> branch to Next_Second
	ret

; 1 second delay w/ button release check
;.equ count1 = 0x6000		; assign hex val for outer loop decrement TODO: dial these in to 1s
;.equ count2 = 0xE1			; assign hex val for inner loop decrement (nice)
.equ count1 = 0x6969
.equ count2 = 0x69
One_Delay:
	ldi R26, low(count1)	; load count1 into outer loop counter (R27:R26)
	ldi R27, high(count1)
D1:
	ldi R25, count2			; load count2 into inner loop counter (R25)

	sbis PIND,6				; If A is pressed -> (A_State <- 1)
	sbr Ctrl_Reg, A_State

	sbrc Ctrl_Reg, 0		; If A_State is 1/Pressed -> Jump to Delay_A_Pressed
	rjmp Delay_A_Pressed

	sbrc Ctrl_Reg, 1		; If B_State is 1/Pressed -> Jump to Delay_B_Pressed
	rjmp Delay_B_Pressed
D2:
	dec R25					; R25 <-- R25 - 1
	brne D2					; If r25 is not 0 -> branch to D2
	sbiw R27:R26, 1			; R27:R26 <-- R27:R26 - 1
	brne D1					; if R27:R26 is not 0 -> branch to D1 
	ret

Delay_A_Pressed:
	sbis PIND, 6			; If A is still pressed -> Jump to D2
	rjmp D2
	cbr Ctrl_Reg, A_State	; Else -> (A_State <- 0), (Run_State <- 0)
	cbr Ctrl_Reg, Run_State
	ret

Delay_B_Pressed:
	sbis PIND, 7			; If B is still pressed -> Jump to D2
	rjmp D2
	cbr Ctrl_Reg, B_State	; Else -> (B_State <- 0)
	ret


;============| Display Digit Subroutine |============
display:
	; backup used registers on stack
	push Disp_Queue			; Push Disp_Queue to stack
	push Disp_Decr			; Push Disp_Decr to stack
	in Disp_Decr, SREG		; Input from SREG -> Disp_Decr
	push Disp_Decr			; Push Disp_Decr to stack
	ldi Disp_Decr, 8		; loop -> test all 8 bits
loop:
	rol Disp_Queue			; rotate left through Carry
	BRCS set_ser			; branch if Carry is set
	cbi PORTB,0				; clear SER (SER -> 0)
rjmp end
set_ser:
	sbi PORTB,0				; set SER (SER -> 1)
end:
	; generate SRCLK pulse
	sbi PORTB,2				; SRCLK on
	nop						; pause to help circuit catch up
	cbi PORTB,2				; SRCLK off
	dec Disp_Decr
	brne loop
	
	; generate RCLK pulse
	sbi PORTB,1				; RCLK on
	nop						; pause to help circuit catch up
	cbi PORTB,1				; RCLK off

	; restore registers from stack
	pop Disp_Decr
	out SREG, Disp_Decr
	pop Disp_Decr
	pop Disp_Queue
	ret
