#include <femtorv32.h>

int filesystem_init() {
  LEDS(1);
  if(sd_init()) {
    printf("Could not initialize SDCard\n");
    return -1;
  }
  fl_init();
  LEDS(2);  
  if(fl_attach_media(
      (fn_diskio_read)sd_readsector,
      (fn_diskio_write)sd_writesector) != FAT_INIT_OK
  ) {
    printf("ERROR: Failed to init file system\n");
    return -1;
  }
  LEDS(4);
  return 0;
}
