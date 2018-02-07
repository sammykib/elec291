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
temp_counter : ds 1
time_counter : ds 1
hundreds_value: ds 1 ;a variable to store hundreds in temperature
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



increment_temp:
jb increment_button,$
Wait_Milli_Seconds(#40)
mov a,temp_counter
cjne a, #0x99, increment_temp_next
mov temp_counter, #0x0
mov a,hundreds_value                  ;mov hundreds to a
cjne a, #0x3, increment_100       ;check if it has reached 400C
mov hundreds_value,#0x0 		          ;reset to zero
jmp increment_temp_next

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

increment_time:
jb increment_button,$
Wait_Milli_Seconds(#40)
mov a,time_counter
cjne a, #0x90, increment_time_next
mov time_counter, #0x0 		          ;reset to zero
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

main:
 mov SP, #0x7F
 lcall LCD_4bit
 jmp start
	; Initialization
start:
	mov temp_counter,#0
	mov time_counter,#0
	mov display_value,#0
	mov hundreds_value,#0
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
	Set_Cursor (2,13)
	Display_BCD (hundreds_value)
	Set_Cursor (2,15)
	Display_BCD (display_value)
   
   	lcall increment_temp
	Wait_Milli_Seconds(#100)   
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
   	Set_Cursor(2,15)
   	Display_BCD (display_value)
	lcall increment_time
   	
   	Wait_Milli_Seconds(#200)   
   	jb enter_button,soak_time_loop_2
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
   	Set_Cursor (2,15)
	Display_BCD (display_value)
	
	lcall increment_time
   	
   	
   	Wait_Milli_Seconds(#200)   
   	jb enter_button,reflow_time_loop_2
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
	Set_Cursor (2,13)
	Display_BCD (hundreds_value)
	Set_Cursor (2,15)
	Display_BCD (display_value)
	
	lcall increment_temp
	Wait_Milli_Seconds(#200)   
   	jb enter_button,reflow_temp_loop_2
   	Set_Cursor(2,1)
   	Send_Constant_String(#empty)
   	Wait_Milli_Seconds(#200) 
    ljmp soak_temp_loop	

END


