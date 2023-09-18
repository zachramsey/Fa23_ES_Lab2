;
; StopwatchLab2.asm
;
; Created: 9/12/2023 7:02:54 PM
; Author : Trey Vokoun & Zach Ramsey
;

.include "m328Pdef.inc" ; tells what microcontroller we have and what instructions it takes

;>>>>>Begin Data Segment<<<<<
.dseg
; Hex Digit Pattern Encoding
digit_patterns:
	.byte 0x3F	; "0" Pattern
	.byte 0x30	; "1" Pattern
	.byte 0x5B	; "2" Pattern
	.byte 0x4F	; "3" Pattern
	.byte 0x66	; "4" Pattern
	.byte 0x6D	; "5" Pattern
	.byte 0x7D	; "6" Pattern
	.byte 0x07	; "7" Pattern
	.byte 0x7F	; "8" Pattern
	.byte 0x67	; "9" Pattern
	.byte 0x77	; "A" Pattern
	.byte 0x7C	; "b" Pattern
	.byte 0x39	; "C" Pattern
	.byte 0x5E	; "d" Pattern
	.byte 0x79	; "E" Pattern
	.byte 0x71	; "F" Pattern
	.byte 0x40	; "-" Pattern
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
.def Ctrl_Reg = R2				; custom state values stored in R2

; state masks
.equ A_Pressed = 0b00000001		; bit 0: button A was pressed   (0:None    | 1:Pressed)
.equ B_Pressed = 0b00000010		; bit 1: button B was pressed   (0:None    | 1:Pressed)
.equ Incr_Mode = 0b00000100		; bit 2: incrementing mode		(0:1s      | 1:10s)
.equ Run_State = 0b00001000		; bit 3: incrementing state     (0:Stopped | 1:Running)
.equ Reset_State = 0b00010000	; bit 5: reset state            (0:None    | 1:Reset
.equ Ovrflw = 0b00100000		; bit 6: overflow state         (0:None    | 1:Overflow)

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

;====================================================


;===================| Main Loop |====================
start:
	ldi R16, hex0			; initially load 0 to display

	sbis PIND,7				; If B is pressed -> Call Press_B
	rcall Press_B


	sbrs Ctrl_Reg, 3		; If running state is 0 -> Call Count_Stopped
	rcall Count_Stopped

	sbrc Ctrl_Reg, 3		; If running state is 1 -> Call Count_Running
	rcall Count_Running


	rcall display			; call display subroutine
	rjmp start				; continue loop
;====================================================


;===========| Running State Subroutine |=============
Count_Running:
	sbrs Ctrl_Reg, Incr_Mode	; If Incr_Mode is 0 -> call 1s_Delay subroutine
	rcall 1s_Delay
	sbrc Ctrl_Reg, Incr_Mode	; If Incr_Mode is 1 -> call 10s_Delay subroutine
	rcall 10s_Delay
	ret							; Return
;====================================================


;===========| Stopped State Subroutine |=============
Count_Stopped:
	sbis PIND,6				; If A is pressed -> Set A_Pressed to 1
	sbi Ctrl_Reg, A_Pressed

	sbrc Ctrl_Reg, 0		; If A_Pressed is 1 -> Call Press_A
	rcall Press_A
	ret							; Return
;====================================================


;========| Handle Pushbutton A Press Event |=========
Press_A:
	
;====================================================


;========| Handle Pushbutton B Press Event |=========
Press_B:
	sbi Ctrl_Reg, B_Pressed	; Set B_Pressed state

	rcall 1s_Delay		; check if released within 1st second
	sbrs Ctrl_Reg, 1	; If B_Pressed is 0 -> branch to Reset_Counter
	rjmp Reset_Counter

	rcall 1s_Delay		; check if released within 2nd second
	sbrs Ctrl_Reg, 1	; If B_Pressed is 0 -> branch to Tggl_Incr_Mode
	rjmp Tggl_Incr_Mode

Wait_Longer:
	rcall 1s_Delay		; check if released in following seconds
	sbrc Ctrl_Reg, 1	; If B_Pressed is 1 -> branch to Clr_Ovrflw
	rjmp Clr_Ovrflw
	rjmp Wait_Longer	; else -> jump back to Wait_Longer

; reset counter
Reset_Counter:
	sbrs Ctrl_Reg, Run_State	; If Run_State is 0 -> Set Reset_state to 1
	sbi Ctrl_Reg, Reset_State
	ret							; return

; toggle increment mode
Toggle_Incr_Mode:
	sbrs Ctrl_Reg, Incr_Mode	; If Incr_Mode is 0 -> Set Incr_Mode to 1
	sbi Ctrl_Reg, Incr_Mode
	sbrc Ctrl_Reg, Incr_Mode	; If Incr_Mode is 1 -> Clr Incr_Mode to 0
	cbr Ctrl_Reg, Incr_Mode
	ret							; return

; clear counter overflow condition ("-")
Clr_Ovrflw:
	sbrs Ctrl_Reg, 6			; If Ovrflw condition is 1 -> Set Reset_state to 1
	sbi Ctrl_Reg, Reset_State
	cbr Ctrl_Reg, Ovrflw		; Clr Ovrflw condition to 0
	ret							; return
;====================================================


;===========| Incrementing Subroutines |=============
; 10 second delay; calls 1s_Delay 10 times
10s_Delay:
	ldi r27,0x0A		; load hex val for decrement (10)
Next_Second:
	dec r27				; r27 <- r27 - 1
	brne Next_Second	; loop if r27 is not '0'
	ret					; return

; 1 second delay w/ button release check
.equ count1 = 0xFA00		; assign hex val for outer loop decrement (64000) TODO: dial these in to 1s
.equ count2 = 0xFA			; assign hex val for inner loop decrement (250)
1s_Delay:
	ldi r25, low(count1)	; load count1 into outer loop counter (r26:r25)
	ldi r26, high(count1)
D1:
	ldi r24, count2			; load count2 into inner loop counter (r24)

	sbis PIND,6				; If A is pressed -> set A_Pressed to 1
	sbi Ctrl_Reg, A_Pressed

	sbrc Ctrl_Reg, 0		; If A_Pressed is 1 -> jump to A_Pressed
	rjmp A_Pressed

	sbrc Ctrl_Reg, 1		; If B_Pressed is 1 -> jump to B_Pressed
	rjmp B_Pressed
D2:
	dec r24					; r24 <-- r24 - 1
	brne D2					; If r24 is not 0 -> branch to D2
	sbiw r26:r25, 1			; r26:r25 <-- r26:r25 - 1
	brne D1					; if r26:r25 is not 0 -> branch to D1 
	ret						; return

A_Pressed:
	sbic PIND,6				; If button A is released -> jump to Release_A
	rjmp A_Released
	rjmp D2					; else -> jump back to D2
A_Released:
	cbr Ctrl_Reg, A_Pressed ; Clear A_Pressed state
	ret						; return early
B_Pressed:
	sbic PIND,7				; If button B is released -> jump to Release_B
	rjmp Release_B
	rjmp D2					; else -> jump back to D2
B_Released:
	cbr Ctrl_Reg, B_Pressed ; Clear B_Pressed state
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
