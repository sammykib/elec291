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
save_value: ds 1
hundreds_value: ds 1 ;a variable to store hundreds in temperature
; These register definitions needed by 'math32.inc'
x:   ds 4
y:   ds 4
bcd: ds 5
Result: ds 2


BSEG
mf: dbit 1

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
$NOLIST
$include(math32.inc) ; A library of LCD related functions and utility macros
$LIST

;                       1234567890123456    <- This helps determine the location of the counter
soak_temp_text:  	db ' Soak   Temp    ',0   
soak_time_text: 	db ' Soak   Time    ',0                
reflow_temp_text:	db ' Reflow  Temp   ',0
reflow_time_text:   db ' Reflow  Time   ',0
timer_message :     db 'Time in Secs:   ',0
temp_message :      db 'Temperature:    ',0 
empty :      		db '                ',0 
time_message:       db 'Time (secs):    ',0 
Max_message_1:      db 'Maximum reached ',0
Max_message_2:      db 'Press 2 to reset',0
Max_message_3:      db 'Or 3+2 to save:)',0




;Buttons to select soak temperatur,soak time,reflow temperature,reflow time and enter button
toggle_button 			equ p2.4
increment_button        equ p2.5
enter_button  			equ p4.5

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
jb increment_button,$
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

increment_time:
jb increment_button,$
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

main:
 mov SP, #0x7F
 lcall LCD_4bit
 ljmp start
	; Initialization
start:
	mov temp_counter,#0x0
	mov time_counter,#0x0
	mov display_value,#0x0
	mov hundreds_value,#0x0
	mov save_value,#0x0
	jnb toggle_button,soak_temp_loop
	ljmp start
	
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
   	;saving
   	mov save_value,temp_counter   
   	lcall save
   	mov soak_temp_value,save_value
   	;clearing screen
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
   	Set_Cursor (2,13)
	Display_BCD (hundreds_value)
   	Set_Cursor(2,15)
   	Display_BCD (display_value)
	lcall increment_time
   	
   	Wait_Milli_Seconds(#200)   
   	jb enter_button,soak_time_loop_2
   	;saving
   	mov save_value,time_counter   
   	lcall save
   	mov soak_time_value,save_value
   	;clearing screen
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
   	Set_Cursor (2,13)
	Display_BCD (hundreds_value)
   	Set_Cursor (2,15)
	Display_BCD (display_value)
	
	lcall increment_time
   	
   	
   	Wait_Milli_Seconds(#200)   
   	jb enter_button,reflow_time_loop_2
   	;saving
   	mov save_value,time_counter   
   	lcall save
   	mov reflow_time_value,save_value
   	;clearing screen
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
   	;saving
   	mov save_value,time_counter   
   	lcall save
   	mov reflow_temp_value,save_value
   	;clearing screen
   	Set_Cursor(2,1)
   	Send_Constant_String(#empty)
   	Wait_Milli_Seconds(#200) 
    ljmp soak_temp_loop	

END


