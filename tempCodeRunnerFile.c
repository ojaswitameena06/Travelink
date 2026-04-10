#include<stdio.h>
#include<string.h>
int main(){
char str[100],rev[100];
int i,j,state=0;
printf("Enter string: ");
scanf("%s",str);
printf("Execution Trace:\n");
for(i=0;i<strlen(str);i++){
printf("q%d --%c--> q1\n",state,str[i]);
state=1;
}
printf("q1 --end--> q2\n");
state=2;
j=0;
for(i=strlen(str)-1;i>=0;i--){
rev[j++]=str[i];
}
rev[j]='\0';
printf("q2 --reverse--> q3\n");
state=3;
printf("Reversed String: %s\n",rev);
return 0;
}