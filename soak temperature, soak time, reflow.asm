;My code for the soak temperatue selection

$NOLIST
$MODLP51
$LIST
; Reset vector
org 0x000H
    ljmp main

putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
SendStringDone:
    ret

cseg
; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS equ P1.1
LCD_RW equ P1.2
LCD_E  equ P1.3
LCD_D4 equ P3.2
LCD_D5 equ P3.3
LCD_D6 equ P3.4
LCD_D7 equ P3.5
$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                           1234567890123456    <- This helps determine the location of the counter
soak_temp_text:  	db ' Soak   Temp    ', 0   ;'xxx Hxx Mxx Sxx'
soak_time_text: 	db ' Soak   Time    ',0                
reflow_temp_text:	db ' Reflow  Temp   ',0
reflow_time_text:   db ' Reflow  Temp   ',0
timer_message :     db 'Hr   Min   Sec  ',0
temp_message :      db 'Temperature:    ',0 


;Buttons to select soak temperatur,soak time,reflow temperature,reflow time and enter button
soak_temp_button 		equ p2.4
soak_time_button        equ p2.5
reflow_temp_button    	equ p2.6
reflow_time_button    	equ p2.7
enter_button  			equ p4.5

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
main:
 mov SP, #0x7F
 lcall LCD_4bit
 jmp start
	; Initialization
start:

   jnb soak_temp_button ,soak_temp_jmp
   jnb soak_time_button,soak_time_jmp
   jnb reflow_temp_button, reflow_temp_jmp
   jnb reflow_time_button, reflow_time_jmp
jmp start

reflow_temp_jmp:
ljmp reflow_temp_loop

reflow_time_jmp:
ljmp reflow_time_loop

soak_temp_jmp:
ljmp soak_temp_loop

soak_time_jmp:
ljmp soak_time_loop
	
	
soak_temp_loop:
   Set_Cursor(1,1)
   Send_Constant_String(#soak_temp_text)
   jnb enter_button,start
   Set_Cursor(2,1)
   Send_Constant_String(#temp_message)
   
   jnb enter_button,$
   ljmp start
   
soak_time_loop:
   Set_Cursor(1,1)
   Send_Constant_String(#soak_time_text)
   jnb enter_button,start_1
   Set_Cursor(2,1)
   Send_Constant_String(#timer_message)
   jnb enter_button,$
   ljmp start_1 
   
start_1:
ljmp start

reflow_time_loop:
   Set_Cursor(1,1)
   Send_Constant_String(#reflow_time_text)
   jnb enter_button,start_1
   Set_Cursor(2,1)
   Send_Constant_String(#timer_message)
   jnb enter_button,$
   ljmp start_1    
	
	
reflow_temp_loop:
   Set_Cursor(1,1)
   Send_Constant_String(#soak_time_text)
   jb enter_button,start_1
   Set_Cursor(2,1)
   Send_Constant_String(#timer_message)
   jnb enter_button,$
   ljmp start_1 	
	
END