#include "filesystem.h"

// Interfacing LiteX low level SDCard access to @ultraembedded's fat_file_io library.
//
// fat_file_io expects:
//   int sd_writesector(uint32_t start_block, uint8_t *buffer, uint32_t sector_count);
//   int sd_readsector(uint32_t start_block, uint8_t *buffer, uint32_t sector_count);
// LiteX liblitesdcard/sdcard.h provides:
//   int sdcard_init(void);
//   void sdcard_read(uint32_t sector, uint32_t count, uint8_t* buf);
//   void sdcard_write(uint32_t sector, uint32_t count, uint8_t* buf);

#include <liblitesdcard/spisdcard.h>
#include <stdio.h>

#ifndef CSR_SPISDCARD_BASE
#error Need to configure LiteX with SDCard support
#endif

static int sdcard_read_adaptor(uint32_t start_block, uint8_t *buffer, uint32_t sector_count) {
   //spisdcard_read(start_block, sector_count, buffer);
   return 1; // How to check errors after sdcard_read ?
}

static int sdcard_write_adaptor(uint32_t start_block, uint8_t *buffer, uint32_t sector_count) {
   //spisdcard_write(start_block, sector_count, buffer);
   return 1; // How to check errors after sdcard_write ?
}

int filesystem_init(void) {
  if(!spisdcard_init()) {
     printf("ERROR:\nCould not init\n SDCard\n");
     return -1;
  } else {
     printf("SDCard OK\n");	
  }
   
  fl_init();
  if(fl_attach_media(
      (fn_diskio_read)sdcard_read_adaptor,
      (fn_diskio_write)sdcard_write_adaptor) != FAT_INIT_OK
  ) {
    printf("ERROR:\nCould not init\nfile system\n");
    return -1;
  }
  return 0;
}

