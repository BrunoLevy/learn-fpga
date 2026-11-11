#include <femtorv32.h>

//#define PS_BASE 0x200000
#define PS_BASE 0xc00000
#define PS_IN(addr)       *(volatile uint32_t*)(PS_BASE + addr)
#define PS_OUT(addr,val)  *(uint32_t*)(PS_BASE + addr)=(val)


#define PS_IN_16(addr)       *(volatile uint16_t*)(PS_BASE + addr)
#define PS_IN_8(addr)       *(volatile uint8_t*)(PS_BASE + addr)

#define PS_OUT_16(addr,val)  *(uint16_t*)(PS_BASE + addr)=(val)
#define PS_OUT_8(addr,val)  *(uint8_t*)(PS_BASE + addr)=(val)

#define AVOID_RAM_ZONE_VARS 655360 //640K
//uint32_t test_address = 0;
uint32_t test_address = 0+AVOID_RAM_ZONE_VARS;
uint32_t test_data_mask = 0x44444444;
uint32_t test_data = 0x12345678;
//uint32_t test_data = 0x01020304;

uint32_t read_back;

uint8_t b0;
uint8_t b1;
uint8_t b2;
uint8_t b3;

uint16_t pass;

int main(void) RV32_SRAMCODE;
int main(void)
{
   printf("\npsram-thrash-qspipsram-test C entry point\n");
   pass = 0;


//   femtosoc_tty_init();
   while (1) {
     //also needed for initial delay where reset done
      printf("DELAY 10 seconds so you can break out\n");
      for (int i = 0; i <10; i++) {
         delay(1000);
         printf(".");
      }
      printf("\nDELAY OVER!!!!!!!\n");
      printf("pass=%d\n",pass++);
#if 1
   uint32_t errors = 0;
   uint32_t suberror = 0;
   uint32_t passwitherrors = 0;
      //blank 4MB
      printf("PSRAM BASE%x\n", PS_BASE);
      printf("Blanking 1MB with test except first %dk\n", AVOID_RAM_ZONE_VARS/1024);
//    for (int i=test_address; i<65536*16*4; i+=4) {
//    for (int i=test_address; i<test_address+65536; i+=4) {
//    for (uint32_t i=test_address; i<65536*16*4; i+=4) {
    for (uint32_t i=test_address; i<65536*16*1; i+=4) {
       if ((i&0xffff) == 0) {
            if (suberror == 0)
               printf("*");
            else {
               printf("!");
               suberror = 0;
            }
       }
       PS_OUT(i,0x55555555);
       uint32_t a = PS_IN(i);
       PS_OUT(i,0xAAAAAAAA);
       uint32_t b = PS_IN(i);
       PS_OUT(i,0xFFFFFFFF);
       uint32_t c = PS_IN(i);
       PS_OUT(i,0x00000000);
       uint32_t d = PS_IN(i);
       if (!(a==0x55555555 && b==0xaaaaaaaa && c==0xFFFFFFFF && d==0x00000000))
       {
        errors++;
        suberror++;
        //don't swamp output
        if (errors <= 10 ) printf("\nerror %x %x %x %x %x\n",i, a, b, c, d);
       }
    }
    if (passwitherrors!=0) printf("\n%d errors this pass. Bad passes %d\n", errors, ++passwitherrors);
    //not as fast as it could be could probably clock psram at twice the rate
    //of the processor
#endif


      printf("\n======================================\n");
      printf("address %x\n", test_address);
     // PS_OUT(test_address,test_data);
     // read_back = PS_IN(test_address);
     // printf("%x = %x [%x] %c\n", test_address, test_data, read_back, read_back != test_data ? '!' : ' ');
     // delay(250);
      PS_OUT_16(test_address+2, 0x1234);
      PS_OUT_16(test_address+0, 0x5678);
      read_back = PS_IN(test_address);
      printf("%x = %x [%x] %c\n", test_address, test_data, read_back, read_back != test_data ? '!' : ' ');
      delay(250);

      PS_OUT_8(test_address+4+3, 0x12);
      PS_OUT_8(test_address+4+2, 0x34);
      PS_OUT_8(test_address+4+1, 0x56);
      PS_OUT_8(test_address+4+0, 0x78);
      read_back = PS_IN(test_address+4);
      printf("%x = %x [%x] %c\n", test_address+4, test_data, read_back, read_back != test_data ? '!' : ' ');
//      delay(250);

      PS_OUT(test_address, 0x12345678);
      b0 = PS_IN_8(test_address);
      b1 = PS_IN_8(test_address+1);
      b2 = PS_IN_8(test_address+2);
      b3 = PS_IN_8(test_address+3);

      printf("b3=%x b2=%x b1=%x b0=%x\n",b3,b2,b1,b0);
      printf("%x\n", ((uint32_t)PS_IN_16(test_address+2))<<16 | PS_IN_16(test_address));


   }
   //should never reach here
   return 0;
}
