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
dseg at 30H
display_value : ds 2
soak_time_value: ds 2
soak_temp_value : ds 2
reflow_temp_value : ds 2
reflow_time_value : ds 2
temp_counter : ds 2
time_counter : ds 2
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

;                       1234567890123456    <- This helps determine the location of the counter
soak_temp_text:  	db ' Soak   Temp    ',0   
soak_time_text: 	db ' Soak   Time    ',0                
reflow_temp_text:	db ' Reflow  Temp   ',0
reflow_time_text:   db ' Reflow  Time   ',0
timer_message :     db 'Time in Secs:   ',0
temp_message :      db 'Temperature:    ',0 
empty :      		db '                ',0 
time_message:       db 'Time in secs:   ',0 



;Buttons to select soak temperatur,soak time,reflow temperature,reflow time and enter button
toggle_button 			equ p2.4
increment_button        equ p2.5

enter_button  			equ p4.5

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;

increment_temp:
jb increment_button,$
Wait_Milli_Seconds(#20)
mov a,temp_counter
cjne a, #255, increment_temp_next
mov temp_counter, #0x0
jmp increment_temp_next

increment_temp_next:
mov a,temp_counter
add a,#1
;da a
mov temp_counter, a
mov display_value,temp_counter
ret 



main:
 mov SP, #0x7F
 lcall LCD_4bit
 jmp start
	; Initialization
start:
	mov temp_counter,#0
	mov temp_counter+1,#0
	mov time_counter,#0
	mov display_value,#0
	mov display_value+1,#0
	jnb toggle_button,soak_temp_loop
	jmp start






	
soak_temp_loop:
	Set_Cursor(1,1)
   	Send_Constant_String(#soak_temp_text)
   	Wait_Milli_Seconds(#200) 
   	jb toggle_button,$
	jnb enter_button,soak_temp_loop_2
	ljmp soak_time_loop

soak_temp_loop_2:	
   	Set_Cursor(1,1)
   	Send_Constant_String(#soak_temp_text)
   	Set_Cursor(2,1)
	Send_Constant_String(#temp_message)
	Set_Cursor (2,14)

	Display_BCD (display_value+0)
	;Display_BCD (display_value+1) 
   
   	lcall increment_temp
	Wait_Milli_Seconds(#40)   
   	jb enter_button,soak_temp_loop_2
   	Set_Cursor(2,1)
   	Send_Constant_String(#empty)
   	Wait_Milli_Seconds(#200) 
   	ljmp start
   
soak_time_loop:
	Set_Cursor(1,1)
   	Send_Constant_String(#soak_time_text)
   	Wait_Milli_Seconds(#200) 
   	jb toggle_button,$
	jnb enter_button,soak_time_loop_2
	ljmp reflow_time_loop
	
	
soak_time_loop_2:	
   	Set_Cursor(1,1)
   	Send_Constant_String(#soak_time_text)
   	Set_Cursor(2,1)
   	Send_Constant_String(#time_message)
   	
   	
   	Wait_Milli_Seconds(#200)   
   	jb enter_button,$
   	Set_Cursor(2,1)
   	Send_Constant_String(#empty)
   	Wait_Milli_Seconds(#200) 
   	ljmp start
   
reflow_time_loop:
	Set_Cursor(1,1)
   	Send_Constant_String(#reflow_time_text)
   	Wait_Milli_Seconds(#200)
   	jb toggle_button,$
	jnb enter_button,reflow_time_loop_2
	ljmp reflow_temp_loop
	
	
	
reflow_time_loop_2:	
   	Set_Cursor(1,1)
   	Send_Constant_String(#reflow_time_text)
   	Set_Cursor(2,1)
   	Send_Constant_String(#time_message)
   	
   	
   	
   	Wait_Milli_Seconds(#200)   
   	jb enter_button,$
   	Set_Cursor(2,1)
   	Send_Constant_String(#empty)
   	Wait_Milli_Seconds(#200) 
   	ljmp start
      
	
	
reflow_temp_loop:
	Set_Cursor(1,1)
   	Send_Constant_String(#reflow_temp_text)
   	Wait_Milli_Seconds(#200) 
   	jb toggle_button,$
	jnb enter_button,reflow_temp_loop_2
	ljmp start
	
	
	
	
reflow_temp_loop_2:	
	Set_Cursor(1,1)
	Send_Constant_String(#reflow_temp_text)
	Set_Cursor(2,1)
	Send_Constant_String(#temp_message)
	
	
	
	Wait_Milli_Seconds(#200)   
   	jb enter_button,$
   	Set_Cursor(2,1)
   	Send_Constant_String(#empty)
   	Wait_Milli_Seconds(#200) 
   ;	ljmp start
    ljmp soak_temp_loop	

END