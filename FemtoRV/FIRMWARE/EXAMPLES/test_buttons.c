#include <femtorv32.h>

int main()  {
   femtosoc_tty_init();
   uint32_t btn_state = IO_IN(IO_BUTTONS);
   for(;;) {
       uint32_t new_state = IO_IN(IO_BUTTONS);
       if(new_state != btn_state) {
	   printf("state=%d\n", new_state);
	   for(int i=0; i<6; ++i) {
	       if(((btn_state & (1 << i)) != (new_state & (1 << i)))) {
		   printf("button %d: %s\n", i, (new_state & (1 << i)) ? "press" : "release");
	       }
	   }
       }

       btn_state = new_state;
   }
}
