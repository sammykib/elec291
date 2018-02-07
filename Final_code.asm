$MODLP52

org 0x0000
	ljmp MainProgram
   
;Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR
	
;Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

;Macro that needs to be used by Macros.inc, as well as LCD_4Bit.inc, so it's included here to work for everything
;---------------------------------;
; Wait 'R2' milliseconds          ;
;---------------------------------;

;-------------------------------------------;
;               Constants                   ;
;-------------------------------------------;

MAX_TEMP_UPPER 	EQU 02	
MAX_TEMP_LOWER 	EQU 35 
CLK            	EQU 22118400
BAUD		EQU 115200
T1LOAD 		EQU (0x100-(CLK/(16*BAUD)))
TIMER0_RATE    	EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD  	EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE    	EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD  	EQU ((65536-(CLK/TIMER2_RATE)))   
 
;-------------------------------------------;
;                Variables                  ;
;-------------------------------------------;

DSEG at 30H

Temperature:	ds 5 ;temperature BCD value
Count1ms: 		ds 2 ; used to count for one second

Secs_BCD:		ds 5 ;These two values are for the displayed runtime
Mins_BCD:		ds 5
Abort_time:		ds 2

BCD_soak_temp: 	 	ds 2 ;BCD value of Soak state temperature setting
BCD_soak_time: 	 	ds 2 ;BCD values of set soak time in seconds
BCD_reflow_temp: 	ds 2
BCD_reflow_time: 	ds 2
SoakTime_Secs:   	ds 2
ReflowTime_Secs: 	ds 2

pwm_count:	 	ds 1
pwm:		 	ds 1
temp_cool:			ds 1
state:				ds 1

;arithmetic variables
x: 			ds 4
y: 		   	ds 4
Result: 		ds 2	

;-------------------------------------------;
;                  Flags                    ;
;-------------------------------------------;

BSEG

;State Flags - Only one flag on at once 
PreheatState_Flag:		dbit 1
SoakState_Flag: 		dbit 1
RampState_Flag:	 		dbit 1
ReflowState_Flag: 		dbit 1
CooldownState_Flag: 	dbit 1

soak_menu_flag: 		dbit 1
reflow_menu_flag:		dbit 1

;Transition Flag turns on when state is changing, and turns off shortly afterwards
;Use with State flags in logic in order to determine what to do eg. beeps to play when x state is (just recently) on and transition flag is on as well
;Transition_Flag: 		dbit 1 

CoolEnoughToOpen_Flag: 		dbit 1
CoolEnoughToTouch_Flag: 	dbit 1
Cooldowntouch_Flag: 		dbit 1
;DoorOpen_Flag: 			dbit 1

mf: 				dbit 1 ;Math Flag for use with math32.inc

Abort_Flag: 			dbit 1
Seconds_flag: 			dbit 1
HalfSecond_Flag:		dbit 1
Length_Flag:			dbit 1

;-------------------------------------------;
;         Pins and Constant Strings         ;
;-------------------------------------------;

CSEG
;ADC Master/Slave pins
CE_ADC  	EQU P2.0
MY_MOSI 	EQU P2.1
MY_MISO 	EQU P2.2
MY_SCLK 	EQU P2.3

;LCD pins
LCD_RS  	EQU P1.2
LCD_RW  	EQU P1.3
LCD_E   	EQU P1.4
LCD_D4  	EQU P3.2
LCD_D5  	EQU P3.3
LCD_D6  	EQU P3.4
LCD_D7  	EQU P3.5

SOUND_OUT EQU P3.7 ;Temp value, modify to whatever pin is attached to speaker
POWER     EQU P2.4
TRANSITION EQU P0.7
;Pushbutton pins
Button_1      	EQU P0.1 ;1
Button_2      	EQU P0.3 ;2
Button_3      	EQU P0.5 ;3
DONE_BUTTON   	EQU P2.5 ;4
BOOT_BUTTON   	EQU P4.5 ;5 

$NOLIST
$include(LCD_4Bit.inc)
$LIST

$NOLIST
$include(Project1_macros.inc) ;Includes extra macros
$LIST

$NOLIST
$include(math32.inc) ; for math functions
$LIST



;-------------------------------------------;
;            SPI Initialization             ;
;-------------------------------------------;

INIT_SPI:
	setb MY_MISO ; Make MISO an input pin
	clr MY_SCLK ; Mode 0,0 default
	ret
DO_SPI_G:
	mov R1, #0 ; Received byte stored in R1
	mov R2, #8 ; Loop counter (8-bits)
DO_SPI_G_LOOP:
	mov a, R0 ; Byte to write is in R0
	rlc a ; Carry flag has bit to write
	mov R0, a
	mov MY_MOSI, c
	setb MY_SCLK ; Transmit
	mov c, MY_MISO ; Read received bit
	mov a, R1 ; Save received bit in R1
	rlc a
	mov R1, a
	clr MY_SCLK
	djnz R2, DO_SPI_G_LOOP
	ret
;-------------------------------------------;
;        Serial Port Initialization         ;
;-------------------------------------------;

;Configure the serial port and baud rate using timer 1
InitSerialPort:
    	;Since the reset button bounces, we need to wait a bit before
    	;sending messages, or risk displaying gibberish!
    	mov R1, #222
    	mov R0, #166
    	djnz R0, $   ; 3 cycles->3*45.21123ns*166=22.51519us
    	djnz R1, $-4 ; 22.51519us*222=4.998ms
    	;Now we can safely proceed with the configuration
	clr	TR1
	anl	TMOD, #0x0f
	orl	TMOD, #0x20
	orl	PCON,#0x80
	mov	TH1,#T1LOAD
	mov	TL1,#T1LOAD
	setb TR1
	mov	SCON,#0x52
    	ret

;-------------------------------------------;
;     Converting Voltage to Temperature     ;
;-------------------------------------------;
ConvertNum:
    	mov y+0,Result
    	mov y+1,Result+1
    	mov y+2,#0
    	mov y+3,#0
    	load_x(37); 1/(41e^-6 * 330) ~= 74
    	lcall mul32
    	lcall hex2bcd
    	ret  
;-------------------------------------------;
;         Timer 0 Initialization            ;
;-------------------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    	setb ET0  ; Enable timer 0 interrupt
    	setb TR0  ; Start timer 0
	ret
	
;-------------------------------------------;
;       	   Timer 0 ISR    		        ;
;-------------------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	; In mode 1 we need to reload the timer.
	clr TR0
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	setb TR0
	cpl SOUND_OUT
	reti
;-------------------------------------------;
;         Timer 2 Initializiation           ;
;-------------------------------------------; 
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov RCAP2H, #high(TIMER2_RELOAD)
	mov RCAP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
    	setb ET2  ; Enable timer 2 interrupt
    	setb TR2  ; Enable timer 2
	ret
;-------------------------------------------;
;                Timer 2 ISR                ;
;-------------------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	inc pwm_count
	clr c
	mov a, pwm_count
	subb a, pwm
	mov POWER, c
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1
	
Inc_Done:
	;Check half second
	mov a, Count1ms+0
	cjne a, #low(500), ContISR2 ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(500), ContISR2
	setb HalfSecond_Flag

ContISR2:
	; Check if a second has passed
	mov a, Count1ms+0
	cjne a, #low(1000), Timer2_ISR_done_redirect ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(1000), Timer2_ISR_done_redirect
	sjmp SecondPassed

Timer2_ISR_done_redirect:
ljmp Timer2_ISR_done

;Increment seconds bcd value every second, and minute every minute, resetting seconds
SecondPassed:
	; 1 second has passed.  Set a flag so the main program knows
	setb Seconds_flag ; Let the main program know a second had passed
	setb HalfSecond_Flag
	jb SoakState_Flag, soak_timer
	jb ReflowState_Flag, reflow_timer
	ljmp ContinueISR
reflow_timer:
	;increment reflow
	mov a, ReflowTime_Secs
	add a,#0x01
	da a
	mov ReflowTime_Secs,a
	cjne a, #0x60, ContinueISR
	mov a, #0x00
	da a
	mov ReflowTime_Secs, a
	sjmp ContinueISR
soak_timer:
	mov a, SoakTime_Secs
	add a,#0x01
	da a
	mov SoakTime_Secs,a
	cjne a,#0x60, ContinueISR
	mov a,#0x00
	da a
	mov SoakTime_Secs,a
ContinueISR:
	
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a

	; Increment the seconds counter
	mov a, Secs_BCD
	add a,#0x01
	da a
	mov Secs_BCD, a
	cjne a,#0x60,Timer2_ISR_done
	mov a,#0x00
	da a
	mov Secs_BCD, a
	cjne a, Mins_BCD, ContinueISR_1
	Preheat_Abort(Temperature+1, Temperature+2)
ContinueISR_1:	
	clr a
	mov a, Mins_BCD
	add a,#0x01
	da a
	mov Mins_BCD,a
Timer2_ISR_done:
	pop psw
	pop acc
	reti
  
  ;Start of the Main Program
  MainProgram:
  	mov SP, #7FH ; Set the stack pointer to the begining of idata
    	mov PMOD, #0 ; Configure all ports in bidirectional mode
    	setb CE_ADC ;ADC enabled when bit is cleared, so start disabled
    
    	;Initialize Serial Port Interface, and LCD
    	lcall InitSerialPort
    	lcall INIT_SPI
    	lcall LCD_4BIT
    	lcall Timer2_Init
    	lcall Timer0_Init
    
    	;Set Flag Initial Values
    	clr Abort_Flag
    	clr SoakState_Flag
    	clr RampState_Flag
    	clr ReflowState_Flag
    	clr CooldownState_Flag
    	setb PreheatState_Flag ;Set Preheat flag to 1 at power on (it won't start preheating until it gets to that loop via Start button)
   
    	clr mf
    	clr CoolEnoughToOpen_Flag
		clr CoolEnoughToTouch_Flag
		clr soak_menu_flag
		clr reflow_menu_flag
		clr POWER
		mov pwm, #0x00
		clr Length_Flag
    
    	;Set Presets
    	mov BCD_soak_temp, 	#0x40
		mov BCD_soak_temp+1, 	#0x01
		mov BCD_reflow_temp, 	#0x19
		mov BCD_reflow_temp+1,	#0x02
	
		mov BCD_soak_time, 	#0x00
		mov BCD_soak_time+1,	#0x01
		mov BCD_reflow_time, 	#0x30
		mov BCD_reflow_time+1,	#0x00
	
		mov Mins_BCD, 		#0x00
		mov Secs_BCD, 		#0x00 
	
	;Zero the runtime of the reflow state
	mov ReflowTime_Secs, 	#0x00
	mov SoakTime_Secs, 	#0x00
	
	;Give temp an initial value so it doesn't auto-abort because of an unknown
	mov Temperature+0, 	#0x00
	mov Temperature+1, 	#0x00
	mov Temperature+2, 	#0x00
	mov temp_cool, #0x60
 	sjmp forever
 
forever:
;get SPI code from Jackey

lcall start_menu
lcall Reflow_States

ljmp forever


Reflow_States:
mov a, state

state_start:
cjne a, #0, state_tosoak
mov pwm, #0
jb Button_1, state_start_done
jnb Button_1, $ ; Wait for key release
mov state, #1
state_start_done:
ret

state_tosoak:
cjne a, #1, state_soak
mov pwm, #100
;mov sec, #0
mov a, BCD_soak_temp
clr c
subb a, Temperature
jnc state_tosoak_done
mov state, #2
setb SoakState_Flag; start timer for soaking
state_tosoak_done:
ret

state_soak:
cjne a, #2, state_topeak
mov pwm, #20
mov a, BCD_soak_time
clr c
subb a, SoakTime_Secs
jnc state_soak_done
mov state, #3
clr SoakState_Flag
state_soak_done:
ret

state_topeak:
cjne a, #3, state_reflow
mov pwm, #100
mov a, BCD_reflow_temp
clr c
subb a, Temperature
jnc state_topeak_done
mov state, #3
setb ReflowState_Flag
state_topeak_done:
ret

state_reflow:
cjne a, #4, state_cool
mov pwm, #20
mov a, BCD_reflow_time
clr c
subb a, ReflowTime_Secs
jnc state_reflow_done
mov state, #5
clr ReflowState_Flag
state_reflow_done:
ret

state_cool:
cjne a, #5, state_done
mov pwm, #0
mov a, temp_cool
clr c
subb a, Temperature
jnc state_cool_done
mov state, #6
state_cool_done:
ret

state_done:
;compliment timer 2 which speaker will be used in for "end beep" output
; Display 'OPEN DOOR' on LCD
mov a, #40H
clr c
subb a, Temperature
jnc state_done_done
;Display "SAFE TEMP"
state_done_done:
ret

 
END
  