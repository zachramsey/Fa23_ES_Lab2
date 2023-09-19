;>>>>>Begin Data Segment<<<<<
.dseg
.org 0x0100
Digit_Patterns: .byte 16	; Hex Digit Pattern Encoding
;>>>>>>End Data Segment<<<<<<


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
;====================================================


;========| Configure custom state register |=========
.def Ctrl_Reg = R18				; custom state values stored in R2

; state masks
.equ A_State = 0b00000001		; bit 0: button A was pressed   (0:None    | 1:Pressed)
.equ B_State = 0b00000010		; bit 1: button B was pressed   (0:None    | 1:Pressed)
.equ Incr_Mode = 0b00000100		; bit 2: incrementing mode		(0:1s      | 1:10s)
.equ Run_State = 0b00001000		; bit 3: incrementing state     (0:Stopped | 1:Running)
.equ Reset_State = 0b00010000	; bit 5: reset state            (0:None    | 1:Reset)
.equ Ovrflw = 0b00100000		; bit 6: overflow state         (0:None    | 1:Overflow)
;====================================================


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

	sbr Ctrl_Reg, Reset_State	; set Reset_State initially
;-----Usage-----
; Set State:
; sbi Ctrl_Reg, (state mask)

; Clear State:
; cbr Ctrl_Reg, (state mask)

; Skip next if bit is 0:
; sbrc Ctrl_Reg, (reg bit #)

; Skip next if bit is 1:
; sbrs Ctrl_Reg, (reg bit #)
;---------------
start:
	sbrc Ctrl_Reg, 5		; if Reset_State is 1 -> call Count_Reset
	rcall Count_Reset

	sbrs Ctrl_Reg, 3		; If running state is 0 -> Call Count_Stopped
	rcall Count_Stopped

	sbrc Ctrl_Reg, 3		; If running state is 1 -> Call Count_Running
	rcall Count_Running

	rcall display			; call display subroutine
rjmp start				; continue loop
;====================================================


;============| Reset State Subroutine |==============
Count_Reset:
	ldi R16, 0x50
	rcall display
	rcall one_delay


	ldi ZH, high(Digit_Patterns)	; Move Z register 
    ldi ZL, low(Digit_Patterns)
	ld R16, Z+	; initially load 0 to display
	ldi R20, 16	; reset counter decrement to 16
	cbr Ctrl_Reg, Reset_State	; Clear Reset_State
	ret
;====================================================


;===========| Running State Subroutine |=============
Count_Running:
	sbrs Ctrl_Reg, Incr_Mode	; If Incr_Mode is 0 -> call one_delay subroutine
	rcall one_delay
	dec R20
	brne loop_count
	ld R16, Z+
	ret							; Return
loop_count:
	sbr Ctrl_Reg, Reset_State	; set Reset_State
	ret
;====================================================


;===========| Stopped State Subroutine |=============
Count_Stopped:
	ldi R16, 0x6D ; Load 's' into display to show stopped is running
	rcall display
	rcall one_delay ; give me time to see the pattern

	sbis PIND,6				; If A is pressed -> Set A_State to 1
	sbr Ctrl_Reg, A_State

	sbrc Ctrl_Reg, 0		; If A_State is 1 -> Call Press_A
	rjmp Press_A
	ret						; Return
Press_A:
	sbic PIND, 6			; If A released -> Clr A_State
	cbr Ctrl_Reg, A_State
	sbic PIND, 6			; If A released -> Set Run_State
	sbr Ctrl_Reg, Run_State
	ret
;====================================================


;===========| Incrementing Subroutines |=============

; 1 second delay w/ button release check
.equ count1 = 0x0AF0		; assign hex val for outer loop decrement was 0x0AF0 (64000) TODO: dial these in to 1s
.equ count2 = 0xFA			; assign hex val for inner loop decrement (250)
one_delay:
	ldi r26, low(count1)	; load count1 into outer loop counter (r27:r26)
	ldi r27, high(count1)
D1:
	ldi r25, count2			; load count2 into inner loop counter (r25)

	sbis PIND,6				; If A is pressed -> set A_State to 1
	sbr Ctrl_Reg, A_State

	sbrc Ctrl_Reg, 0		; If A_State is 1 -> jump to A_Pressed
	rjmp A_Pressed
D2:
	dec r25					; r25 <-- r25 - 1
	brne D2					; If r24 is not 0 -> branch to D2
	sbiw r27:r26, 1			; r27:r26 <-- r27:r26 - 1
	brne D1					; if r26:r25 is not 0 -> branch to D1 
ret						; return

A_Pressed:
	sbic PIND,6				; If button A is released -> jump to Release_A
	rjmp A_Released
	rjmp D2					; else -> jump back to D2
A_Released:
	cbr Ctrl_Reg, A_State	; Clear A_State
	cbr Ctrl_Reg, Run_state	; Clear Run_State
ret						; return early
;====================================================


;=======| Shift Reg/7-Seg Display Subroutine |=======
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
;====================================================
;>>>>>>End Code Segment<<<<<<
