#include <reg51.h>
sfr lcddata=0xA0; //P2 = LCD D7...D0 pins (A0=address of P2)
sbit RS=P0^0;
sbit RW=P0^1;
sbit EN=P0^2;
sbit busy=P2^7;
sfr adcdata=0x90; //P1 = ADC pins OUT1...OUT8 (90=address of P1)
sbit Start=P3^7;
sbit EOC=P3^6;
sbit OE=P3^5;
sbit Heater=P0^3;
sbit ADCClock=P3^4;
sbit EINT1=TCON^2;
sbit EINT0=TCON^0;

code unsigned char string[] = {"Temperature:"};
code unsigned char desstring[] = {"Desired:"};
unsigned int a=2,b=1,c=4;//init values for desired temp

void plusButton();
void minusButton();

void ADCClk () interrupt 1 {//interr for timer 0
	ADCClock = ~ADCClock;
}

void ButtonMinus() interrupt 2 {//interr for INT1 external
	minusButton();
}

void ButtonPlus() interrupt 0 {//interr for INT0 external
	plusButton();
}

void clockADC();
void displayMessage(unsigned char code *dchar);
void command(unsigned char value);
void ready();
void Delay(unsigned int delaytime);
void writeToLCD(unsigned char value);
void readyConversion();
void readTemp();
void findNumber(unsigned int x);
void shiftLineToRight();
void shift2ndLineToRight();
void shift1stLineToRight();
void displayDesiredTemp();
void heater(unsigned int x, unsigned int y, unsigned int z);
unsigned int formDesiredTemp();

void main() {
	IE=0x87;//enable interr for INT0, INT1, timer 0
	EINT1=1;//enable INT1 when a transition from HIGH in LOW
	EINT0=1;//enable INT0 when a transition from HIGH in LOW
	clockADC();
	command(0x38);//init LCD
	command(0x0E);//place cursor
	command(0x01);//clear display
	displayMessage(&string);
	command(0xC0);//move in 2nd row
	displayMessage(&desstring);
	shift2ndLineToRight();
	displayDesiredTemp();
	while(1){
		shift1stLineToRight();
		readTemp();
		command(0x10);//shift the cursor to the left 4 positions to display the new value
		command(0x10);
		command(0x10);
		command(0x10);
	}
}

void command(unsigned char value) {
	ready();
	lcddata=value;//put on P2 the value of the command
	RS=0;
	RW=0;//prepare to write command
	EN=1;
	Delay(1);
	EN=0;
}

void ready() {
	EN=0;
	busy=1;//make P2.7 input port (D7 of LCD)
	RS=0;
	RW=1;//prepare to read from LCD
	while(busy==1) {
		EN=0;
		Delay(1);
		EN=1;
	}
	EN=0;
}

void Delay(unsigned int delaytime) {
	unsigned int i,j;
	for (i=0;i<delaytime;i++)
	for (j=0;j<1275;j++);//delay of approx 12ms
}

void displayMessage(unsigned char code *string){
	while(*string!=0){
		writeToLCD(*string);
		string++;
	}
}

void writeToLCD(unsigned char value){
	ready();
	lcddata=value;
	RS=1;
	RW=0;//prepare to write
	EN=1;
	Delay(1);
	EN=0;
}

void readTemp(){
	unsigned int x;
	adcdata=0xFF;//input port
	readyConversion();//see if cnversion is ready
	x=adcdata;
	OE=0;//bring OE back to 0
	findNumber(x);
}

void readyConversion(){
	Delay(50);
	Start=1;//start the conversion
	Delay(1);
	Start=0;
	EOC=1;//make P3.6 input port
	//check if EOC=LOW to HIGH -> ready conversion
	while(EOC!=0){
		}
	while(EOC!=1){
	  }
	OE=1;//set OE to 1 to put result on output lines
	Delay(1);
}

void findNumber(unsigned int x){
	unsigned int y;
	unsigned int d,e,f;//to save real temp
	d=x/51;//save digit of tens
	y=x%51;
	e=y/5;//save digit of units
	writeToLCD(d+0x30);//digit of tens
	writeToLCD(e+0x30);//digit of units
	writeToLCD(0x2E);//put the dot
	y=x%0x33;
	y=y%0x05;
	y=y*0x02;//digit after comma, only even
	f=y;//save digit after comma
	writeToLCD(y+0x30);
	heater(d,e,f);
}

void clockADC() {
	//ADC clock frequency = 100kHz
	//T=10us => Ton=Toff=5us
	//5/1.085 = 5
	//load in TH0=-5d
	TMOD=0x02;//mode 2 for timer 0
	TH0=-5;
	TR0=1;//start timer 0
}

void shiftLineToRight(){
	unsigned int i;
	for (i=0;i<12;i++){
		command(0x14);//jump over 12 positions
	}
}

void shift2ndLineToRight(){
	command(0xC0);//start of 2nd line
	shiftLineToRight();
}

void shift1stLineToRight(){
	command(0x80);
	shiftLineToRight();
}


void displayDesiredTemp() {//write the desired temp
	writeToLCD(a+0x30);
	writeToLCD(b+0x30);
	writeToLCD('.');
	writeToLCD(c+0x30);
}

void heater(unsigned int d, unsigned int e, unsigned int f){
	unsigned int x;
	x=formDesiredTemp();//form number corresp to desired temp
	d*=100;
	e*=10;
	d=d+e;
	d=d+f;//form number corresp to real temp
	if (d<x)
		Heater=1;
	else
		Heater=0;
}

unsigned int formDesiredTemp(){
	unsigned int x,y,z;
	x=a;
	y=b;
	z=c;
	x*=100;
	y*=10;
	x=x+y;
	x=x+z;
	return x;
}

void plusButton(){
	shift2ndLineToRight();
	if(a<5){//verify if max is not reached
		if (c!=8)//if comma hasn't reached max value, increment
			c+=2;
		else//else increment unit
			if (b!=9){//if units hasn't reached max value
				c=0;//put comma in 0
				b++;
			}
			else
				if (a!=5){//if tens hasn't reached max value
					b=0;//reset units
					c=0;//reset comma
					a++;
				}
	}
	displayDesiredTemp();
}

void minusButton(){
	shift2ndLineToRight();
	if (c!=0)//if comma is not zero, decrement
		c-=2;
	else//else decr units
		if (b!=0){//if units hasn't reached min value
			c=8;//reset comma
			b--;//decr units
		}
		else
			if (a!=0){//if tens hasn't reached min value
				c=8;//reset comma
				b=9;//reset units
				a--;//decr tens
			}
	displayDesiredTemp();
}
