
#include <femtorv32.h>


static const int data[] = {
   0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
};

int main() {

   int i=0;
   for(;;) {
      i=i+1;
      int j = i>>14;
      int k = data[(j&15)];
      LEDS(k);
   }

}
