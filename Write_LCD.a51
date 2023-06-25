	org 0000h
	ljmp main
	org 0003h;INT0 interrupt service routine
	ljmp buttonPlus	
	org 000Bh;address of interrupt timer 0
	cpl P3.4;pin where the ADC Clock is connected
	reti
	org 0013h;INT1 interreupt service routine
	ljmp buttonMinus 
	
	org 30h

main:
	mov IE,#10000111b;enable INT1, INT0, T0 interrupts
	acall clockADC
	setb TCON.2;enable INT1 when a transition from HIGH in LOW
	setb TCON.0;enable INT0 when a transition from HIGH in LOW
	mov P1,#0FFh;make P1 input port
	;initial value for desired temperature
	mov r3,#2h;digit of tens of desired temp
	mov r4,#1h;digit of units of desired temp
	mov r5,#4h;digit after comma
	mov A,#38h;init LCD
	acall command
	mov A,#0Eh;place cursor
	acall command
	mov A,#01h;clear display
	acall command
	mov dptr,#1000h;read a string
	label:
		mov a,#0
		movc a,@a+dptr;read letter by letter
	    jz finish
		acall display
		inc dptr
		sjmp label
	finish:
		mov a,#0C0h;force cursor to 2nd line
		acall command
		mov dptr,#2000h;read the string for desired temperature
		label1:
			mov a,#0h
			movc a,@a+dptr;
			jz finish1
			acall display
			inc dptr
			sjmp label1
	finish1:
		acall shift2ndLineRight
		acall displayDesired;display desired temp
	convert:
		acall shift1stLineRight;to display real temp
		acall findTemp
		mov a,#10h;shift cursor to the left to display a new value of the temp
		acall command
		mov a,#10h
		acall command
		mov a,#10h
		acall command
		mov a,#10h
		acall command
		
		sjmp convert		

command:
	acall ready;see if the LCD is ready
	mov P2,A;put command to data lines
	clr P0.0;put RS in 0 for command
	clr P0.1;put R/W in 0 for command
	setb P0.2;put E in 1
	nop
	nop
	clr P0.2;make E H->L
	ret

display:
	acall ready
	mov P2,A;put data on data lines
	setb P0.0;set RS in 1 for writing
	clr P0.1;put R/W in 0 for writing
	setb P0.2
	nop
	nop
	clr P0.2
	ret

ready:
	clr P0.2;put E LOW
	nop
	nop
	setb P2.7;make P2.7 (D7) input port
	clr P0.0;put RS in 0 for command register
	setb P0.1;set R/W in 1 for reading
	;read command register and check busy flag
	back:
		clr P0.2
		nop
		nop
		setb P0.2;switch E L->H and wait for command to be executed
		jb P2.7,back;until busy flag is 0
	clr P0.2
	ret
	
readyConversion:
	setb P3.7;start the conversion (H->L)
	nop
	nop
	clr P3.7
	setb P3.6;make pin 6 of port 3 input port to read EOC signal
	;check if EOC gets low to high
	t:
		jb P3.6,t
	nop
	nop
	r:
		jnb P3.6,r
	setb P3.5;set OE High to have the rsult on the output lines
	ret	
	
findTemp:
	acall readyConversion;see if conversion is ready
	mov a,P1;take value from ADC
	clr P3.5;set OE Low
	
	mov b,#33h
	div ab;divide a by 33h (51 in decimal = 50 possible hex numbers 
;that have same tens number + 1 to make the division correct
;e.g. 32h = 50d and is 09.8 degrees, so tens 0) and store in a the quotient
;the quotient is the tens of the temperature number
	mov r0,a;save digit of tens
	add a,#30h;convert to ASCII
	acall display
	
	mov a,b;get b
	mov b,#5h;divide by 5 beacuse for each unit, there are 5
;possible hex values
	div ab
	mov r1,a;save digit of units
	add a,#30h
	acall display
	
	mov a,#'.'
	acall display

	mov a,b;get the remainders of the division
	mov b,#2h
	mul ab;multiply by 2 
;beacuse the no after comma are multiples of 2
;store lower 8-bits in a
	mov r2,a;save digit after comma
	add a,#30h
	acall display
	acall heater
	ret

clockADC:
	;ADC clock frequency = 100kHz
	;T=10us => Ton=Toff=5us
	;5/1.085 = 5
	;load in TH0=-5d
	mov TMOD,#02h;mode 2 for timer 0
	mov TH0,#-5d
	setb TR0;start timer
ret


displayDesired:
	mov a,r3
	add a,#30h
	acall display
	mov a,r4
	add a,#30h
	acall display
	mov a,#'.'
	acall display
	mov a,r5
	add a,#30h
	acall display
ret

buttonPlus:
plus:
	acall shift2ndLineRight
	cjne r3,#5h,below50
	acall displayDesired
	reti
	below50:
	cjne r5,#8h,commaplus
	cjne r4,#9h,unitsplus
	cjne r3,#5h,tensplus
	acall displayDesired
	reti
	commaplus:
		inc r5
		inc r5
		sjmp ok1
	unitsplus:
		inc r4
		mov r5,#0h
		sjmp ok1
	tensplus:
		inc r3
		mov r4,#0h
		mov r5,#0h
		sjmp ok1
	ok1:
	
	acall displayDesired

reti

buttonMinus:
minus:
	acall shift2ndLineRight
	cjne r5,#0h,commaminus
	cjne r4,#0h,unitsminus
	cjne r3,#0h,tensminus
	acall displayDesired
	reti
	commaminus:
		dec r5
		dec r5
		sjmp ok
	unitsminus:
		dec r4
		mov r5,#8h
		sjmp ok
	tensminus:
		dec r3
		mov r4,#9h
		mov r5,#8h
		sjmp ok
	ok:
	
	acall displayDesired

reti

shiftToRightLine:
	mov b,#0Ch;jump over the already written message (12 characters)
	rightShift:
		mov a,#14h
		acall command
		dec b
		mov a,b
	cjne a,#0h,rightShift
	ret

shift1stLineRight:
	mov a,#80h;force cursor to 1st line
	acall command
	acall shiftToRightLine
	
ret

shift2ndLineRight:
	mov a,#0C0h
	acall command
	acall shiftToRightLine

ret

heater:
	;divide real temp by desired temp
	mov b,r3
	mov a,b
	jz verifytens;verify divison by 0
	mov a,r0
	div ab
	jnz verifytens;if quotient is 0
	;real temp<desired temp
	
	acall turnOnHeater
	ret
	
	verifytens:
	mov a,r0
	subb a,r3
	jnz goodtemp;if tens are equal, comapare
	;the units. If not, real temp>desired temp
	
	units:
	;mov a,r1
	mov b,r4
	mov a,b
	jz verifyunits;verify divison by 0
	mov a,r1
	div ab
	jnz verifyunits;if quotient 0
	;real temp<desired temp
	
	acall turnOnHeater
	ret
	
	verifyunits:
	mov a,r1
	subb a,r4
	jnz goodtemp;if units are equal
	;verify digit after comma
	
	comma:
	;mov a,r2
	mov b,r5
	mov a,b
	jz verifycomma;verify divison by 0
	mov a,r2
	div ab
	jnz verifycomma;if quotient 0
	;real temp<desired temp
	
	acall turnOnHeater
	ret
	
	verifycomma:
	mov a,r2
	subb a,r5
	jnz goodtemp;if digits after
	;comma are equal => same temp
	
	goodtemp:
	acall turnOffHeater

ret

turnOnHeater:
	setb P0.3
ret

turnOffHeater:
	clr P0.3
ret	
	

org 1000h
	string: db 'Temperature:',0

org 2000h
	s: db 'Desired: ',0
	
end