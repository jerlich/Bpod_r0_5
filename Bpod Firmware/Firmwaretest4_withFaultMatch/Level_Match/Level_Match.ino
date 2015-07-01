
void setup() {
pinMode(31,OUTPUT);
pinMode(33,OUTPUT);
  Serial.begin(9600);  
}

void loop() {
 int level =analogRead(A0);
 // Serial.println(faultMatch());
//Serial.println(level);
switch(faultMatch())
{//case 1:
//Serial.println( "nothing in");
//break;
case 2:
Serial.println( "upper one");
digitalWrite(33, HIGH);
delay(1000);
//
break;
case 3:
Serial.println( "lower one");


break;
//case 4:
//Serial.println( " In");
//break;
}
digitalWrite(31, HIGH);
digitalWrite(31, LOW);
digitalWrite(33, LOW);
}

int faultMatch(){
  int flag;
  
if ((analogRead(A0))>1000)
{flag=1;
}
 if((800>(analogRead(A0)))&&((analogRead(A0))>650))
{flag=2;
}

 if((500>(analogRead(A0)))&&((analogRead(A0))>400))
{flag=3;
}
 if((390>(analogRead(A0))))
{flag=4;
}
//else if ((level>690)&&(level))

return flag;
}
