;$MODLP52
$NOLIST
$MODLP51
$LIST

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

Temp:			ds 5 ;temperature BCD value
bcd: 			ds 5
Thermo:			ds 2
amb: 			ds 5
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

;variables from selecting soak+reflow code
display_value : ds 2
soak_time_value: ds 2
soak_temp_value : ds 2
reflow_temp_value : ds 2
reflow_time_value : ds 2
temp_counter : ds 1
time_counter : ds 1
hundreds_value: ds 1 ;a variable to store hundreds in temperature
save_value:     ds 1

pwm_count:	 	ds 1
pwm:		 	ds 1
temp_cool:		ds 1
state:			ds 1
settings_num:	ds 1

;arithmetic variables
x: 			ds 4
y: 		   	ds 4
Result:     ds 2	

;-------------------------------------------;
;                  Flags                    ;
;-------------------------------------------;

BSEG

;State Flags - Only one flag on at once 
SoakState_Flag: 		dbit 1
RampState_Flag:	 		dbit 1
ReflowState_Flag: 		dbit 1
CooldownState_Flag: 	dbit 1
running_flag:           dbit 1
flash_flag:				dbit 1
CoolEnoughToOpen_Flag: 		dbit 1
CoolEnoughToTouch_Flag: 	dbit 1
Cooldowntouch_Flag: 		dbit 1

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

FT93C66_CE   EQU P2.4 ;might need to Pick a different pin
FT93C66_MOSI EQU P2.1 
FT93C66_MISO EQU P2.2
FT93C66_SCLK EQU P2.3 

;LCD pins
LCD_RS  	EQU P1.1
LCD_RW  	EQU P1.2
LCD_E   	EQU P1.3
LCD_D4  	EQU P3.2
LCD_D5  	EQU P3.3
LCD_D6  	EQU P3.4
LCD_D7  	EQU P3.5

SOUND_OUT EQU P3.7 ;Temp value, modify to whatever pin is attached to speaker
POWER     EQU P2.4
TRANSITION EQU P0.7
;Pushbutton pins
toggle_button    EQU P2.5 ;1
increment_button EQU P2.6 ;2
enter_button     EQU P2.7 ;3
DONE_BUTTON   	 EQU P0.1 ;4
BOOT_BUTTON   	 EQU P4.5 ;5 

$NOLIST
$include(LCD_4Bit.inc)
$LIST

;$NOLIST
;$include(Project1_macros.inc) ;Includes extra macros
;$LIST

$NOLIST
$include(math32.inc) ; for math functions
$LIST
$NOLIST
$include(FT93C66.inc); for non-volitile memory chip 93C66 commands
$LIST

;messages for display
def_men:			db 'default',0
soak_temp_text:  	db ' Soak   Temp    ',0   
soak_time_text: 	db ' Soak   Time    ',0                
reflow_temp_text:	db ' Reflow  Temp   ',0
reflow_time_text:   db ' Reflow  Time   ',0
soak_temp_text2:  	db 'Soak Temp:  ',0   
soak_time_text2: 	db 'Soak Time:  ',0                
reflow_temp_text2:	db 'ReflowTemp: ',0
reflow_time_text2:  db 'ReflowTime: ',0
timer_message :     db 'Time in Secs:   ',0
temp_message :      db 'Temperature:    ',0 
empty :      		db '                ',0 
main_menu_1:        db 'Reflow Profile:',0
main_menu_2:        db '[1]New [2]Load  ',0
running_menu_1:     db 'State:',0
running_menu_2:     db '  m  s',0
time_message:       db 'Time (secs):    ',0 
Max_message_1:      db 'Maximum reached ',0
Max_message_2:      db 'Press 2 to reset',0
Max_message_3:      db 'Or 3 to save:)  ',0
new_profile_string: db 'New:            ',0
load_profile_string:db 'Load:           ',0
profile_options:    db '0 1 2 default   ',0
profile_options2:   db '0 1 2           ',0
show_1:             db '1               ',0
show_2:             db '2               ',0
show_3:             db '3               ',0

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
	;clr TR0
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	;setb TR0
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
	cpl flash_flag
	setb Seconds_flag ; Let the main program know a second had passed
	setb HalfSecond_Flag
	jb SoakState_Flag, soak_timer
	jb ReflowState_Flag, reflow_timer
	ljmp ContinueISR
reflow_timer:
	;increment reflow
	mov a, ReflowTime_Secs
	add a,#01
	da a
	mov ReflowTime_Secs,a
	cjne a, #60, ContinueISR
	mov a, #00
	da a
	mov ReflowTime_Secs, a
	sjmp ContinueISR
soak_timer:
	mov a, SoakTime_Secs
	add a,#01
	da a
	mov SoakTime_Secs,a
	cjne a,#60, ContinueISR
	mov a,#00
	da a
	mov SoakTime_Secs,a
ContinueISR:
	
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a

	; Increment the seconds counter
	mov a, Secs_BCD
	add a,#01
	da a
	mov Secs_BCD, a
	cjne a,#60,Timer2_ISR_done
	mov a,#00
	da a
	mov Secs_BCD, a
	cjne a, Mins_BCD, ContinueISR_1
	;Preheat_Abort(Temperature+1, Temperature+2)
ContinueISR_1:	
	clr a
	mov a, Mins_BCD
	add a,#01
	da a
	mov Mins_BCD,a
SendThingsToPuttyandMath:
; Get Thermocouple data
    clr CE_ADC
    mov R0, #00000001B; Start bit:1
    lcall DO_SPI_G
    mov R0, #10010000B ; Single ended, read channel 1
    lcall DO_SPI_G
    mov a, R1          ; R1 contains bits 8 and 9
    anl a, #00000011B  ; We need only the two least significant bits
    mov Thermo+1, a    ; Save result high.
    mov R0, #55H ; It doesn't matter what we transmit...
    lcall DO_SPI_G
    mov Thermo, R1     
; R1 contains bits 0 to 7.  Save result low.
    setb CE_ADC
;    lcall Delay
    lcall Do_Something_With_Result2
Timer2_ISR_done:
	pop psw
	pop acc
	reti
  
  ;Start of the Main Program
  MainProgram:
  		setb EA
  	    mov SP, #7FH ; Set the stack pointer to the begining of idata
    	;mov PMOD, #0 ; Configure all ports in bidirectional mode
    	setb CE_ADC ;ADC enabled when bit is cleared, so start disabled
        mov P0M0, #0
        mov P0M1, #0 
    	;Initialize Serial Port Interface, and LCD
    	lcall InitSerialPort
    	lcall INIT_SPI
    	lcall FT93C66_INIT_SPI
    	lcall LCD_4BIT
    	lcall Timer2_Init
    	lcall Timer0_Init
    
    	;Set Flag Initial Values
    	clr Abort_Flag
    	clr SoakState_Flag
    	clr RampState_Flag
    	clr ReflowState_Flag
    	clr CooldownState_Flag
    	;setb PreheatState_Flag ;Set Preheat flag to 1 at power on (it won't start preheating until it gets to that loop via Start button)
   
    	clr mf
		clr POWER
		clr TR0
		mov pwm, #0x00
		mov a,#0x00
		mov settings_num,a
    
    	;Set Presets
    	mov BCD_soak_temp, 		#160
		;mov BCD_soak_temp+1, 	#0x01
		mov BCD_reflow_temp, 	#255
	;	mov BCD_reflow_temp+1,	#0x02
	
		mov BCD_soak_time, 		#60
		;mov BCD_soak_time+1,	#0x01
		mov BCD_reflow_time, 	#30
		;mov BCD_reflow_time+1,	#0x00
		lcall Save_values
	
		mov Mins_BCD, 		#0x00
		mov Secs_BCD, 		#0x00 
	
	;Zero the runtime of the reflow state
	mov ReflowTime_Secs, #0x00
	mov SoakTime_Secs, 	#0x00
	
	;Give temp an initial value so it doesn't auto-abort because of an unknown
	mov Temp+0, 	#0x00
	mov Temp+1, 	#0x00
	mov Temp+2, 	#0x00
	mov temp_cool, #0x60
 	sjmp forever
 
forever:
    mov temp_counter,#0x0
	mov time_counter,#0x0
	mov display_value,#0x0
	mov hundreds_value,#0x0
	mov save_value,#0x0
;get SPI code from Jackey

;jb start_menu_button,next
;jnb start_menu_button,next
;jb start_menu_button,$
;lcall menu branch
lcall main_menu
;jnb toggle_button,soak_temp_loop
;Wait_Milli_Seconds(#50)
;jb toggle_button,soak_temp_loop  this code was used for testing
;jb toggle_button,$

next:
lcall Reflow_States

ljmp forever

soak_temp_loop:	
   	Set_Cursor(1,1)
   	Send_Constant_String(#soak_temp_text)
   	Set_Cursor(2,1)
	Send_Constant_String(#temp_message)
	Set_Cursor (2,13)
	Display_BCD (hundreds_value)
	Set_Cursor (2,15)
	Display_BCD (display_value)
	
	lcall increment_temp
	Wait_Milli_Seconds(#100) 
	
    jb toggle_button,soak_temp_loop_2
    lcall reset_values
    Wait_Milli_Seconds(#100)
	ljmp soak_time_loop
	
	soak_temp_loop_2:
   	jb enter_button,soak_temp_loop
   	;saving
   	mov save_value,temp_counter   
   	lcall save
   	mov BCD_soak_temp,save_value
   	;clearing screen
   	Set_Cursor(2,1)    
   	Send_Constant_String(#empty)
   	Wait_Milli_Seconds(#100)
   	lcall reset_values 
   	ljmp soak_time_loop
   
soak_time_loop:	
   	Set_Cursor(1,1)
   	Send_Constant_String(#soak_time_text)
   	Set_Cursor(2,1)
   	Send_Constant_String(#time_message)
   	Set_Cursor (2,13)
	Display_BCD (hundreds_value)
   	Set_Cursor(2,15)
   	Display_BCD (display_value)
   	
	lcall increment_time
   	Wait_Milli_Seconds(#100)
   	
   	jb toggle_button,soak_time_loop_2
   	lcall reset_values
   	Wait_Milli_Seconds(#100)
   	ljmp reflow_time_loop 
   	
   	soak_time_loop_2:    
   	jb enter_button,soak_time_loop
   	;saving
   	mov save_value,time_counter   
   	lcall save
   	mov BCD_soak_time,save_value
   	;clearing screen
   	Set_Cursor(2,1)
   	Send_Constant_String(#empty)
   	Wait_Milli_Seconds(#100)
   	lcall reset_values 
   	ljmp reflow_time_loop
   
reflow_time_loop:	
   	Set_Cursor(1,1)
   	Send_Constant_String(#reflow_time_text)
   	Set_Cursor(2,1)
   	Send_Constant_String(#time_message)
   	Set_Cursor (2,13)
	Display_BCD (hundreds_value)
   	Set_Cursor (2,15)
	Display_BCD (display_value)
	
	lcall increment_time
   	Wait_Milli_Seconds(#100)
   	
   	jb toggle_button,reflow_time_loop_2
   	lcall reset_values
   	Wait_Milli_Seconds(#100)
   	ljmp reflow_temp_loop
   	
   	reflow_time_loop_2:    
   	jb enter_button,reflow_time_loop
   	;saving
   	mov save_value,time_counter   
   	lcall save
   	mov BCD_reflow_time,save_value
   	;clearing screen
   	Set_Cursor(2,1)
   	Send_Constant_String(#empty)
   	Wait_Milli_Seconds(#100)
   	lcall reset_values 
   	ljmp reflow_temp_loop
      
reset_values:
    mov temp_counter,#0x0
	mov time_counter,#0x0
	mov display_value,#0x0
	mov hundreds_value,#0x0
	mov save_value,#0x0
ret	
	
reflow_temp_loop:	
	Set_Cursor(1,1)
	Send_Constant_String(#reflow_temp_text)
	Set_Cursor(2,1)
	Send_Constant_String(#temp_message)
	Set_Cursor (2,13)
	Display_BCD (hundreds_value)
	Set_Cursor (2,15)
	Display_BCD (display_value)
	
	lcall increment_temp
	Wait_Milli_Seconds(#100)
	
	jb toggle_button,reflow_temp_loop_2
	lcall reset_values
	Wait_Milli_Seconds(#100)
	ljmp Display_settings
	
	reflow_temp_loop_2:    
   	jb enter_button,reflow_temp_loop
   	;saving
   	mov save_value,time_counter   
   	lcall save
   	mov BCD_reflow_temp,save_value
   	;clearing screen
   	Set_Cursor(2,1)
   	Send_Constant_String(#empty)
   	Wait_Milli_Seconds(#100)
   	lcall reset_values 
    ljmp Display_settings	
    
Reflow_States:
mov a, state

state_start:
cjne a, #0, state_tosoak
mov pwm, #0
;jb Button_1, state_start_done //commented for debugging
;jnb Button_1, $ ; Wait for key release
setb TR0
Wait_Milli_Seconds(#50)
clr TR0
mov state, #1
state_start_done:
ret

state_tosoak:
cjne a, #1, state_soak
mov pwm, #100
;mov sec, #0
mov a, BCD_soak_temp
clr c
subb a, Temp
jnc state_tosoak_done
mov state, #2
setb TR0
Wait_Milli_Seconds(#50)
clr TR0
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
setb TR0
Wait_Milli_Seconds(#100)
clr TR0
mov state, #3
clr SoakState_Flag
state_soak_done:
ret

state_topeak:
cjne a, #3, state_reflow
mov pwm, #100
mov a, BCD_reflow_temp
clr c
subb a, Temp
jnc state_topeak_done
setb TR0
Wait_Milli_Seconds(#100)
clr TR0
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
setb TR0
Wait_Milli_Seconds(#100)
clr TR0
mov state, #5
clr ReflowState_Flag
state_reflow_done:
ret

state_cool:
cjne a, #5, state_done
mov pwm, #0
mov a, temp_cool
clr c
subb a, Temp
jnc state_cool_done
setb TR0
Wait_Milli_Seconds(#200)
Wait_Milli_Seconds(#200)
clr TR0
mov state, #6
state_cool_done:
ret

state_done:
;compliment timer 2 which speaker will be used in for "end beep" output
; Display 'OPEN DOOR' on LCD
clr running_flag
mov a, #40H
clr c
subb a, Temp
jnc state_done_done
setb TR0
Wait_Milli_Seconds(#50)
clr TR0
setb TR0
Wait_Milli_Seconds(#50)
clr TR0
setb TR0
Wait_Milli_Seconds(#50)
clr TR0
setb TR0
Wait_Milli_Seconds(#50)
clr TR0
setb TR0
Wait_Milli_Seconds(#50)
clr TR0
setb TR0
Wait_Milli_Seconds(#50)
clr TR0
mov state, #0
;Display "SAFE TEMP"
state_done_done:
ret

Save_values:
    lcall FT93C66_Write_Enable
    mov a,settings_num
    CJNE a,#0x0,settingone
    mov dptr,#0x0 
    jmp store
    settingone:
    CJNE a,#0x1,settingtwo
    mov dptr,#0x4 
    jmp store
    settingtwo:
    CJNE a,#0x2,settingthree
    mov dptr,#0x8 
    jmp store
    settingthree:
    CJNE a,#0x3,returnfromsetting
    mov dptr,#0x12 
    
    store:
    mov a,BCD_soak_time  ; Value to write at location
    lcall FT93C66_Write
    inc dptr
    
    mov a,BCD_soak_temp  ; Value to write at location
    lcall FT93C66_Write
    inc dptr
    
    mov a,BCD_reflow_time  ; Value to write at location
    lcall FT93C66_Write
    inc dptr
    
    mov a,BCD_reflow_time  ; Value to write at location
    lcall FT93C66_Write
    returnfromsetting:
    ret
  
Read_values:
    lcall FT93C66_Write_Enable
    mov a,settings_num
    CJNE a,#0x0,settingone2
    mov dptr,#0x0 
    jmp reading
    settingone2:
    CJNE a,#0x1,settingtwo2
    mov dptr,#0x4 
    jmp reading
    settingtwo2:
    CJNE a,#0x2,settingthree2
    mov dptr,#0x8 
    jmp reading
    settingthree2:
    CJNE a,#0x3,returnfromsetting
    mov dptr,#0x12 
    
	reading:
    lcall FT93C66_Read
    mov BCD_soak_time,a  ; Value to write at location
   
    inc dptr
    lcall FT93C66_Read
    mov BCD_soak_temp,a  ; Value to write at location
   
    inc dptr
    lcall FT93C66_Read
    mov BCD_reflow_time,a  ; Value to write at location
   
    inc dptr
    lcall FT93C66_Read
    mov BCD_reflow_time,a  ; Value to write at location
    ret
    
    Do_Something_With_Result2:
	Load_x(0)
	Load_y(0)
    mov x+0, Thermo+0
    mov x+1, Thermo+1

	Load_y(47)
    lcall mul32
	Load_y(2400)
	lcall add32
	lcall hex2Temp
    ;mov DPTR, #space
    ;lcall SendString ;CODE FOR DEBUGGING ONLY
	Send_BCD(Temp+2)
    Send_BCD(Temp+1)
    Send_BCD(Temp+0)
    ret

hex2Temp:
	push acc
	push psw
	push AR0
	push AR1
	push AR2
	
	clr a
	mov Temp+0, a ; Initialize BCD to 00-00-00-00-00 
	mov Temp+1, a
	mov Temp+2, a
	mov Temp+3, a
	mov Temp+4, a
	mov r2, #32  ; Loop counter.

hex2Temp_L0:
	; Shift binary left	
	mov a, x+3
	mov c, acc.7 ; This way x remains unchanged!
	mov r1, #4
	mov r0, #(x+0)
hex2Temp_L1:
	mov a, @r0
	rlc a
	mov @r0, a
	inc r0
	djnz r1, hex2Temp_L1
    
	; Perform bcd + bcd + carry using BCD arithmetic
	mov r1, #5
	mov r0, #(Temp+0)
hex2Temp_L2:   
	mov a, @r0
	addc a, @r0
	da a
	mov @r0, a
	inc r0
	djnz r1, hex2Temp_L2

	djnz r2, hex2Temp_L0

	pop AR2
	pop AR1
	pop AR0
	pop psw
	pop acc
	ret
Do_Something_With_Result:
    Set_Cursor(1,4)
	Load_x(0)
	Load_y(0)
	mov x+0, Result
	mov x+1, Result+1
	Load_y(4096)
	lcall mul32
	Load_y(1023)
	lcall div32
	Load_y(2730)
	lcall sub32
	lcall hex2bcd
	Send_BCD(bcd+2)
	Send_BCD(bcd+1)
	Send_BCD(bcd+0)
    ret
max_time:
	mov a,time_counter
	cjne a, #0x20, return_max_time
	mov a,#0x0
	mov hundreds_value,a
	mov time_counter,a
	lcall flicker_message
	return_max_time:
	ret

	flicker_message:
	Set_Cursor(1,1)
	Send_Constant_String(#Max_message_1)
	Set_Cursor(2,1)
	Send_Constant_String(#Max_message_2)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Set_Cursor(2,1)
	Send_Constant_String(#Max_message_3)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	jb increment_button,go_flicker  
	ret
go_flicker:
	ljmp flicker_message

max_temp:
	mov a,temp_counter
	cjne a, #0x50, return_max_temp
	mov a,#0x0
	mov hundreds_value,a
	mov temp_counter,a
	lcall flicker_message
	return_max_temp:
	ret



save:
	Load_x(hundreds_value)
	Load_y(100)
	lcall mul32
	Load_y(save_value)
	lcall add32
	mov save_value,x
	ret
	

increment_temp:
	jb increment_button,quick_return
	sjmp continue
	
quick_return:
ret
	
continue:	
	Wait_Milli_Seconds(#40)
	mov a,hundreds_value
	cjne a, #0x2,temp_not_50
	lcall max_temp


temp_not_50:
	mov a,temp_counter
	cjne a, #0x99, increment_temp_next
	mov temp_counter, #0x0
	mov a,hundreds_value                  ;mov hundreds to a
	cjne a, #0x3, increment_100       ;check if it has reached 400C
	mov hundreds_value,#0x0 		          ;reset to zero
	ljmp increment_temp_next

increment_100: 
	add a,#0x1
	mov hundreds_value,a                   	  ;increment 100 when accumulator reaches 99
	mov a,#0x0
	mov temp_counter, a
	mov display_value,temp_counter 
	ret
	
increment_temp_next:
	mov a,temp_counter
	add a,#0x1
	da a
	mov temp_counter, a
	mov display_value,temp_counter
	
	ret 
	
return_inc:
ret

increment_time:
	jb increment_button,quick_return_2
	sjmp continue_2
	
quick_return_2:
ret

continue_2:
	Wait_Milli_Seconds(#40)
	mov a,hundreds_value
	cjne a, #0x1,time_not_20
	lcall max_time
	
time_not_20:
	mov a,time_counter
	cjne a, #0x99, increment_time_next
	mov time_counter, #0x0 		          ;reset to zero
	mov a,hundreds_value                  ;mov hundreds to a
	cjne a, #0x2, increment_100_time       ;check if it has reached 400C
	mov hundreds_value,#0x0 		          ;reset to zero
	ljmp increment_temp_next 
	
increment_100_time: 
	add a,#0x1
	mov hundreds_value,a                   	  ;increment 100 when accumulator reaches 99
mov a,#0x0
mov time_counter, a
mov display_value,time_counter 
ret
	
increment_time_next:
mov a,time_counter
add a,#0x1
da a
mov time_counter, a
mov display_value,time_counter
ret 

;code to save the values
;save:
;ret
;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
Delay:
    Wait_Milli_Seconds(#100)
    Wait_Milli_Seconds(#100)
    ret


running_menu: 
	Wait_Milli_Seconds(#50)
    setb running_flag
    Set_Cursor(1,1)
    Send_Constant_String(#running_menu_1)
    Set_Cursor(2,1)
    Send_Constant_String(#running_menu_2)
    Set_Cursor(2,1)
    Display_BCD(Mins_BCD)
    Set_Cursor(2,4)
    Display_BCD(Secs_BCD)
ret

main_menu:
 	Wait_Milli_Seconds(#200)
     Set_Cursor(1,1)
     Send_Constant_String(#main_menu_1)
     Set_Cursor(2,1)
     Send_Constant_String(#main_menu_2)
      ;button to go to write a new profile
      jnb toggle_button,new_profile
      Wait_Milli_Seconds(#50)
      ;jnb toggle_button,new_profile  
      ;jb toggle_button,$
      ;button to go to load preset profile
      jnb increment_button,load_profile_jump
      Wait_Milli_Seconds(#50)
      ;jb increment_button,load_profile_jump
      ;jnb increment_button,$
  ret

load_profile_jump:  
ljmp load_profile

new_profile:
   Wait_Milli_Seconds(#80)
   Set_Cursor(1,1)
   Send_Constant_String(#new_profile_string)
   mov a,settings_num
   Set_Cursor(1,10)
   Display_BCD(settings_num)
   butt_press2:
   Set_Cursor(2,1)
   Send_Constant_String(#profile_options2)

   jnb increment_button,inc_settings2
   Wait_Milli_Seconds(#20)
   jnb enter_button,to_main2
   Wait_Milli_Seconds(#20)
   ljmp new_profile
   
   to_main2:
   lcall  Save_values
   ljmp soak_temp_loop
inc_settings2:
Wait_Milli_Seconds(#50)
  mov a, settings_num
  inc a
  CJNE a,#3,notfour2
  mov a,#0x0
notfour2:
  mov settings_num,a
  ljmp new_profile

   
load_profile: 
   Wait_Milli_Seconds(#80)
   Set_Cursor(1,1)
   Send_Constant_String(#load_profile_string)
   mov a,settings_num
   CJNE a,#0x3,dispset
   Set_Cursor(1,10)
   Send_Constant_String(#def_men)
   Set_Cursor(2,1)
   Send_Constant_String(#profile_options)
   jmp butt_press
   dispset:
   Set_Cursor(1,10)
   Display_BCD(settings_num)
   Set_Cursor(2,1)
   Send_Constant_String(#profile_options)
   butt_press:
   ;profile selection
 ;  jnb toggle_button,load_profile_1
 ;  Wait_Milli_Seconds(#50)
   jnb increment_button,inc_settings
   Wait_Milli_Seconds(#50)
   jnb enter_button,Display_settings
   Wait_Milli_Seconds(#50)
   ljmp butt_press
to_main:
lcall Read_values
ljmp main_menu
;load_profile_1:
;  Set_Cursor(1,1)
;  Send_Constant_String(#show_1)
;  ljmp load_profile_1
;
;load_profile_2:
;  Set_Cursor(1,1)
;  Send_Constant_String(#show_2)
;ljmp load_profile_2
;
;load_profile_3:
;  Set_Cursor(1,1)
;  Send_Constant_String(#show_3)
;ljmp load_profile_3

inc_settings:
Wait_Milli_Seconds(#50)
  mov a, settings_num
  inc a
  CJNE a,#4,notfour
  mov a,#0x0
notfour:
  mov settings_num,a
  ljmp load_profile
 putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret
Display_settings:
	 flashy1:
	 Set_Cursor(1,1)
	 Send_Constant_String(#empty)	 
	 Set_Cursor(2,1)
	 Send_Constant_String(#empty)
	 Set_Cursor(1,1)
	 Send_Constant_String(#soak_temp_text2)
	 Load_X(0)
	 mov a,BCD_soak_temp
	 mov x,a
	 lcall hex2bcd
	 Display_BCD(bcd+1)
	 Display_BCD(bcd)
	 Set_Cursor(2,1)
	 Send_Constant_String(#soak_time_text2)
	 Load_X(0)
	 mov a,BCD_soak_time
	 mov x,a
	 lcall hex2bcd
	 Display_BCD(bcd+1)
	 Display_BCD(bcd)
	 look4:
	 jnb flash_flag,flashy2
	 jmp look4
	 flashy2:
	 Set_Cursor(1,1)
	 Send_Constant_String(#empty)	 
	 Set_Cursor(2,1)
	 Send_Constant_String(#empty)
	 Set_Cursor(1,1)
	 Send_Constant_String(#reflow_temp_text2)
	 Load_X(0)
	 mov a,BCD_reflow_temp
	 mov x,a
	 lcall hex2bcd
	 Display_BCD(bcd+1)
	 Display_BCD(bcd)
	 Set_Cursor(2,1)
	 Send_Constant_String(#reflow_time_text2)
	 Load_X(0)
	 mov a,BCD_reflow_time
	 mov x,a
	 lcall hex2bcd
	 Display_BCD(bcd+1)
	 Display_BCD(bcd)
	 look5:
	 jb flash_flag,jump_up
	 jmp look5
	 jump_up:
	 ljmp flashy1

END