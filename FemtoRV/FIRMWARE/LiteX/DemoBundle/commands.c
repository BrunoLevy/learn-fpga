#include "command.h"
#include <generated/csr.h>
#include <stdio.h>
#include <string.h>

static void reboot(int nb_args, char** args) {
   ctrl_reset_write(1);
}
define_command(reboot, reboot, "reboot the CPU", 0);


#ifdef CSR_VIDEO_FRAMEBUFFER_BASE
static void framebuffer(int nb_args, char** args) {
   if (nb_args < 1) {
      printf("framebuffer on|off\n");
      return;
   }
   if(!strcmp(args[0],"on")) {
      video_framebuffer_vtg_enable_write(1);
      video_framebuffer_dma_enable_write(1);
   } else if(!strcmp(args[0],"off")) {
      video_framebuffer_vtg_enable_write(0);
      video_framebuffer_dma_enable_write(0);
   } else {
      printf("framebuffer on|off");
   }
}
define_command(framebuffer, framebuffer, "turn framebuffer on/off", 0);
#endif