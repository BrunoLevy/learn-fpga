#include "command.h"

#include <lite_elf.h>

#include <liblitesdcard/sdcard.h>
#include <liblitesdcard/spisdcard.h>
#include <libfatfs/ff.h>

#include <generated/csr.h>

#include <stdio.h>
#include <string.h>

static void reboot(int nb_args, char** args) {
   ctrl_reset_write(1);
}
define_command(reboot, reboot, "reboot the CPU", 0);


#ifdef CSR_VIDEO_FRAMEBUFFER_BASE
static void framebuffer(int nb_args, char** args) {
   if (nb_args == 0) {
       printf(
	  "framebuffer is %s\n",
	  video_framebuffer_dma_enable_read() ? "on" : "off"
       );
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

#ifdef CSR_ESP32_BASE
static void esp32(int nb_args, char** args) {
   if (nb_args == 0) {
       printf("esp32 is %s\n", esp32_enable_read() ? "on" : "off");
       return;
   }
   if(!strcmp(args[0],"on")) {
       esp32_enable_write(1);
   } else if(!strcmp(args[0],"off")) {
       esp32_enable_write(0);
#ifdef CSR_SPISDCARD_BASE
       spisdcard_init();
#endif      
   } else {
       printf("esp32 on|off");
   }
}
define_command(esp32, esp32, "turn ESP32 on/off", 0);
#endif


static void esp32_off(void) {
#ifdef CSR_ESP32_BASE
    if(esp32_enable_read()) {
	printf("esp32 is on, stopping it\n");
	printf("(mutually exclusive with SDCard access)\n");
	printf("use \'esp32 on\' to reactive it\n");
        printf("\n");
    }
    esp32_enable_write(0);
#ifdef CSR_SPISDCARD_BASE
       spisdcard_init();
#endif      
#endif    
}


#if defined(CSR_SPISDCARD_BASE) || defined(CSR_SDCORE_BASE)
static void catalog(int nb_args, char** args) {
    FRESULT fr;
    FATFS fs;
    DIR dir;
    FILINFO filinfo;

    esp32_off();
    fr = f_mount(&fs,"",1);
    if(fr != FR_OK) {
	printf("Could not mount filesystem\n");
	return;
    }

    fr = f_opendir(&dir,nb_args == 0 ? "/" : args[0]);
    if(fr != FR_OK) {
	printf("opendir error\n");
	return;
    }

    while((fr = f_readdir(&dir, &filinfo)) == FR_OK && filinfo.fname[0]) {
	printf("%s %d\n", filinfo.fname, (int)(filinfo.fsize));
    } 

    f_closedir(&dir);
}
define_command(catalog, catalog, "list files on SDCard", 0);

typedef void(*main_fptr)(int argc, char** argv);

static void run(int nb_args, char** args) {
   FRESULT fr;
   FATFS fs;
   Elf32Info info;

   esp32_off();
   
   if(nb_args < 1) {
      printf("run <filename> <args>\n");
      return;
   }
   
   fr = f_mount(&fs,"",1);
   if(fr != FR_OK) {
      printf("Could not mount filesystem\n");
      return;
   }

   if(elf32_load(args[0],&info) != ELF32_OK) {
      printf("could not load %s\n",args[0]);
      return;
   }
   (*(main_fptr)(info.text_address))(nb_args, args);
}
define_command(run, run, "run an ELF file", 0);


#endif
