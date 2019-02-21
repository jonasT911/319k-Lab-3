;****************** main.s ***************
; Program written by: Teddy Hsieh and Jonas Traweek
; Date Created: 2/4/2017
; Last Modified: 1/18/2019
; Brief description of the program
;   The LED toggles at 2 Hz and a varying duty-cycle
; Hardware connections (External: One button and one LED)
;  PE2 is Button input  (1 means pressed, 0 means not pressed)
;  PE3 is LED output (1 activates external LED on protoboard)
;  PF4 is builtin button SW1 on Launchpad (Internal) 
;        Negative Logic (0 means pressed, 1 means not pressed)
; Overall functionality of this system is to operate like this
;   1) Make PE3 an output and make PE2 and PF4 inputs.
;   2) The system starts with the the LED toggling at 2Hz,
;      which is 2 times per second with a duty-cycle of 30%.
;      Therefore, the LED is ON for 150ms and off for 350 ms.
;   3) When the button (PE2) is pressed-and-released increase
;      the duty cycle by 20% (modulo 100%). Therefore for each
;      press-and-release the duty cycle changes from 30% to 70% to 70%
;      to 90% to 10% to 30% so on
;   4) Implement a "breathing LED" when SW1 (PF4) on the Launchpad is pressed:
;      a) Be creative and play around with what "breathing" means.
;         An example of "breathing" is most computers power LED in sleep mode
;         (e.g., https://www.youtube.com/watch?v=ZT6siXyIjvQ).
;      b) When (PF4) is released while in breathing mode, resume BREATHEing at 2Hz.
;         The duty cycle can either match the most recent duty-
;         cycle or reset to 30%.
;      TIP: debugging the breathing LED algorithm using the real board.
; PortE device registers
GPIO_PORTE_DATA_R  EQU 0x400243FC
GPIO_PORTE_DIR_R   EQU 0x40024400
GPIO_PORTE_AFSEL_R EQU 0x40024420
GPIO_PORTE_DEN_R   EQU 0x4002451C
; PortF device registers
GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_AFSEL_R EQU 0x40025420
GPIO_PORTF_PUR_R   EQU 0x40025510
GPIO_PORTF_DEN_R   EQU 0x4002551C
GPIO_PORTF_LOCK_R  EQU 0x40025520
GPIO_PORTF_CR_R    EQU 0x40025524
GPIO_LOCK_KEY      EQU 0x4C4F434B  ; Unlocks the GPIO_CR register
SYSCTL_RCGCGPIO_R  EQU 0x400FE608
	
TIME_UNIT		   EQU 0x00058BD0  ; number of WAIT cycles for 50ms
B_TIME_UNIT		   EQU 0x00005000  ; number of B_WAIT cycles for 20us
B_STAGE_CYCLE	   EQU 0x00000001  ; iterations per breathe stage

       IMPORT  TExaS_Init
       THUMB
       AREA    DATA, ALIGN=2
;global variables go here
DUTY_CYCLE		SPACE 1				;tracks duty cycle %.
BREATHE_DUTY	SPACE 1				;(SIGNED) tracks duty cycle in BREATHE mode
BREATHE_INCR	SPACE 1				;how much BREATHE_DUTY should change by
	
TIME_R RN R2						;keeps #cycles of wait to run
UNIT_R RN R3						; = TIME_UNIT
B_COUNT RN R12						;how much BREATHE_DUTY changes 
       AREA    |.text|, CODE, READONLY, ALIGN=2
       THUMB
       EXPORT  Start
Start
 ; TExaS_Init sets bus clock at 80 MHz
     BL  TExaS_Init ; voltmeter, scope on PD3
 
	;DUTY_CYCLE = 30%
	LDR R0, =DUTY_CYCLE
	MOV R1, #0x03
	STRB R1, [R0]
	
	;BREATH_DUTY = 0
	LDR R0, =BREATHE_DUTY
	MOV R1, #0x00
	STRB R1, [R0]
	
	;clock
	LDR R0, =SYSCTL_RCGCGPIO_R
	LDR R1, [R0]
	ORR R1, #0x30
	STR R1, [R0]
	
	NOP
	NOP
	
	;DEN
	LDR R0, =GPIO_PORTE_DEN_R
	LDR R1, [R0]
	ORR R1, #0x0C
	STR R1, [R0]
	LDR R0, =GPIO_PORTF_DEN_R
	LDR R1, [R0]
	ORR R1, #0x10
	STR R1, [R0]
	
	;DIR: PE3 OUT, PF4/PE2 IN
	LDR R0, =GPIO_PORTE_DIR_R
	LDR R1, [R0]
	ORR R1, #0x08
	AND R1, #0xFB
	STR R1, [R0]
	LDR R0, =GPIO_PORTF_DIR_R
	LDR R1, [R0]
	AND R1, #0xEF
	STR R1, [R0]
	
	;Unlocks PortF - Credits to Caleb Kovatch
	LDR R0, =GPIO_LOCK_KEY
	LDR R1, =GPIO_PORTF_LOCK_R
	STR R0, [R1]
	LDR R0, =GPIO_PORTF_CR_R
	LDR R1, [R0]
	ORR R1, #0xFF
	STR R1, [R0]
	LDR R0, =GPIO_PORTF_PUR_R
	LDR R1, [R0]
	ORR R1, #0x10
	STR R1, [R0]

    CPSIE  I    ; TExaS voltmeter, scope runs on interrupts
	LDR UNIT_R, = TIME_UNIT
loop  

	;Set PE3 high
	LDR R0, =GPIO_PORTE_DATA_R
	LDR R1, [R0]
	ORR R1, #0x08
	STR R1, [R0]
	
	;wait time = TIME_UNIT * DUTY_CYCLE
	LDR TIME_R, =DUTY_CYCLE
	LDRB TIME_R, [TIME_R]
	LDR UNIT_R, =TIME_UNIT
	MUL TIME_R, TIME_R, UNIT_R
	BL WAIT
	
	;clear PE3
	LDR R0, =GPIO_PORTE_DATA_R
	LDR R1, [R0]
	AND R1, #0xF7
	STR R1, [R0]
	
	;wait time = TIME_UNIT * (10 - DUTY_CYCLE)
	LDR TIME_R, =DUTY_CYCLE
	LDRB TIME_R, [TIME_R]
	RSB TIME_R, TIME_R, #0x0A
	LDR UNIT_R, =TIME_UNIT
	MUL TIME_R, TIME_R, UNIT_R
	BL WAIT
	
     B    loop
      
	  
	;wait for time specified by TIME_R
	;exits to RELEASE when PE2 is pressed
	;switch to BREATHE mode when PF4 is pressed
WAIT
	LDR R0, =GPIO_PORTE_DATA_R
	LDR R1, [R0]
	AND R1, R1, #0x04
	CMP R1, #0x00
	BNE RELEASE
	
	LDR R0, =GPIO_PORTF_DATA_R
	LDR R1, [R0]
	AND R1, R1, #0x10
	CMP R1, #0x00
	BEQ BREATHE
	
	SUBS TIME_R, TIME_R, #0x01
	BGT WAIT
	
	BX LR

RELEASE
	;loop until PE2 is released
	LDR R0, =GPIO_PORTE_DATA_R
	LDR R1, [R0]
	AND R1, R1, #0x04
	CMP R1, #0x00
	BNE RELEASE
	
	;increment DUTY_CYCLE upon release
	LDR R0, = DUTY_CYCLE
	LDRB R1, [R0]
	ADD R1, R1, #0x02
	CMP R1, #0x09	;mod 10
	BLS R_EXIT
	MOV R1, #0x01

R_EXIT
	STRB R1, [R0]
	B loop	;forced restart, no need to use LR
	
;=================================================================;
BREATHE
	;Varies brightness of LED periodically until PF4 is released
	LDR B_COUNT, =B_STAGE_CYCLE
	
	LDR R0, =BREATHE_INCR
	MOV R1, #0x05
	STR R1, [R0]
	
B_LOOP
	;PE3 on for BREATHE_DUTY * B_TIME_UNIT
	LDR R0, =GPIO_PORTE_DATA_R
	LDR R1, [R0]
	ORR R1, R1, #0x08
	STR R1, [R0]
	
	LDR TIME_R, =BREATHE_DUTY
	LDRSB TIME_R, [TIME_R]
	LDR UNIT_R, =B_TIME_UNIT
	MUL TIME_R, TIME_R, UNIT_R	
	BL B_WAIT
	
	;PE3 off for (100 - BREATHE_DUTY) * B_TIME_UNIT
	LDR R0, =GPIO_PORTE_DATA_R
	LDR R1, [R0]
	AND R1, R1, #0xF7
	STR R1, [R0]
	
	LDR TIME_R, =BREATHE_DUTY
	LDRSB TIME_R, [TIME_R]
	RSB TIME_R, TIME_R, #0x64
	LDR UNIT_R, =B_TIME_UNIT
	MUL TIME_R, TIME_R, UNIT_R
	BL B_WAIT
	
	;iterate B_COUNT
	SUBS B_COUNT, B_COUNT, #0x01
	BGT B_TEST					;if (B_COUNT > 0) B_COUNT--
	LDR B_COUNT, =B_STAGE_CYCLE	;else B_COUNT reset & change BREATHE_DUTY  			
	
	;change BREATHE_DUTY
	LDR R0, =BREATHE_DUTY
	LDRSB R1, [R0]
	LDR R2, =BREATHE_INCR
	LDRSB R2, [R2]
	ADD R1, R1, R2
	STRB R1, [R0]
	
	CMP R1, #0x64 			;if (BREATE_DUTY == 0 || == 100) 
	BGE INVERT_INCR			; INCR * -1
	CMP R1, #0x00
	BGT B_TEST

INVERT_INCR
	LDR R0, =BREATHE_INCR
	LDRSB R1, [R0]
	MOV R2, #-1
	MUL R1,R1, R2
	STRB R1, [R0]

B_TEST
	;Test PF4 release once per cycle
	LDR R0, =GPIO_PORTF_DATA_R
	LDR R1, [R0]
	AND R1, R1, #0x10
	CMP R1, #0x00
	BNE loop	;force restart to next cycle in "loop"
	
	B B_LOOP
	
B_WAIT 
	;Wait for BREATHE mode. No need to push/pop LR due to forced restart
	SUBS TIME_R, TIME_R, #0x01
	BGT B_WAIT
	
	BX LR
	
;=================================================================;
	
     ALIGN      ; make sure the end of this section is aligned
     END        ; end of file

