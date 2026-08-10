#include <femtorv32.h>

#define PS_BASE 0xc00000
#define PS_IN(addr)       *(volatile uint32_t*)(PS_BASE + addr)
#define PS_OUT(addr,val)  *(uint32_t*)(PS_BASE + addr)=(val)

//uint32_t test_address = 0;
#define AVOID_RAM_ZONE_VARS 655360 //640K
uint32_t test_address = 0 + AVOID_RAM_ZONE_VARS;
uint32_t test_data_mask = 0x44444444;
//uint32_t test_data = 0x12345678;
uint32_t test_data = 0x01020304;

uint32_t read_back;

int main(void)
{
//   femtosoc_tty_init();
   while (1) {
      printf("======================================\n");
      printf("address %x\n", test_address);
      PS_OUT(test_address,test_data);
      read_back = PS_IN(test_address);
      printf("%x = %x [%x] %c\n", test_address, test_data, read_back, read_back != test_data ? '!' : ' ');
      delay(250);
      PS_OUT(test_address,test_data+test_data_mask);
      read_back = PS_IN(test_address);
      printf("%x = %x [%x] %c\n", test_address, test_data+test_data_mask, read_back, read_back != test_data+test_data_mask ? '!' : ' ');
      delay(250);
      PS_OUT(test_address,test_data_mask);
      read_back = PS_IN(test_address);
      printf("%x = %x [%x] %c\n", test_address, test_data_mask, read_back, read_back != test_data_mask ? '!' : ' ');
      delay(250);
      PS_OUT(test_address,test_data_mask<<1);
      read_back = PS_IN(test_address);
      printf("%x = %x [%x] %c\n", test_address, test_data_mask<<1, read_back, read_back != test_data_mask<<1 ? '!' : ' ');
      delay(250);
      test_address+=4;
      printf("address %x\n", test_address);
      PS_OUT(test_address,test_data);
      read_back = PS_IN(test_address);
      printf("%x = %x [%x] %c\n", test_address, test_data, read_back, read_back != test_data ? '!' : ' ');
      delay(250);
      PS_OUT(test_address,test_data+test_data_mask);
      read_back = PS_IN(test_address);
      printf("%x = %x [%x] %c\n", test_address, test_data+test_data_mask, read_back, read_back != test_data+test_data_mask ? '!' : ' ');
      delay(250);
      PS_OUT(test_address,test_data_mask);
      read_back = PS_IN(test_address);
      printf("%x = %x [%x] %c\n", test_address, test_data_mask, read_back, read_back != test_data_mask ? '!' : ' ');
      delay(250);
      PS_OUT(test_address,test_data_mask<<1);
      read_back = PS_IN(test_address);
      printf("%x = %x [%x] %c\n", test_address, test_data_mask<<1, read_back, read_back != test_data_mask<<1 ? '!' : ' ');
      delay(250);
      test_address -= 4;
   }
   //should never reach here
   return 0;
}
