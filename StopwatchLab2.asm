;
; StopwatchLab2.asm
;
; Created: 9/12/2023 7:02:54 PM
; Author : Trey Vokoun & Zach Ramsey
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

; Configure custom state register

;---------Usage----------
; Set State
; sbi Control_Reg, (state mask)

; Clear State
; cbr Control_Reg, (state mask)

; Read State
; sbrc CustomStateReg, (reg bit #)  ; Skip if bit is clear (not set)
; Code for State A
;------------------------

.def Control_Reg = R2				; custom state values stored in R2

; state masks
.equ Button_Released = 0b00000001	; bit 0 represents if button has been released (0:pressed | 1:released)
.equ Increment_Mode = 0b00000010	; bit 1 represents current increment mode (0:1s | 1:10s)

;------------------------

; begin main loop
start:
	ldi R16, hex0	; initially load 0 to display

	SBIS PIND,6		; Skip next if A is 1
	rcall Press_A	; call Press_A

	SBIS PIND,7		; Skip next if B is 1
	rcall Press_B	; call Press_B

	rcall display	; call display subroutine
rjmp start


; handle pushbutton A press down
Press_A:
	ret				; return

; handle pushbutton B press down
Press_B:
	rcall check_release_1s		; check if released under 1 second
	BRTS Reset_Counter			; if T flag set -> branch to Reset_Counter

	rcall check_release_1s		; check if released between 1 & 2 seconds
	BRTS Toggle_Incr_Mode		; branch to Reset_Counter if T set

	rcall check_release_1s		; check if released over 2 seconds
	BRTS Clear_Count_Overflow	; branch to Reset_Counter if T set

; reset counter to 0
; TODO: implement stop condition check and reset
Reset_Counter:
	ret				; return

; toggle increment mode between 1s & 10s
; TODO: implement mode change functionality
Toggle_Incr_Mode:
	ret				; return

; clear counter overflow condition ("-")
; TODO: implement check for overflow and reset
Clear_Count_Overflow:
	ret				; return


; check if button pushed within 1 s of call
.equ count1 = 0xFA00	; assign hex val for outer loop decrement (64000)
.equ count2 = 0xFA		; assign hex val for inner loop decrement (250)
check_release_1s:
	ldi r25, low(count1)	; load count1 into outer loop counter (r26:r25)
	ldi r26, high(count1)
D1:
	sbic PIND,7		; skip next if B is 0
	rjmp Release_B	; jump to Release_B

	ldi r24, count2 ; load count2 into inner loop counter (r24
D2:
	dec r24			; r24 <-- r24 - 1
	brne D2			; branch to D2 if result is not "0"
	sbiw r26:r25, 1 ; r26:r25 <-- r26:r25 - 1
	brne D1			; branch to D1 if result is not "0"
	ret				; return

Release_B:
	set				; set T flag in sreg (TODO: need to change to use custom state register)
	ret				; return early


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
