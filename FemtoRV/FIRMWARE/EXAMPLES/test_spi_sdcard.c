
#include <femtorv32.h>
#include <fat_io_lib/fat_filelib.h>

int main() {
    femtosoc_tty_init();

    if(sd_init()) {
	printf("Could not initialize SDCard\n");
	return 1;
    }
    printf("SDCard OK\n");
    fl_init();
    if(fl_attach_media((fn_diskio_read)sd_readsector, (fn_diskio_write)sd_writesector) != FAT_INIT_OK) {
	printf("ERROR: Failed to init file system\n");
	return -1;
    }
    printf("FileSystem OK\n");
    fl_listdirectory("/");
    printf("done.\n");   
    
    
/*
    
    if(sd_init()) {
	printf("Could not initialize SDCard\n");
	return 1;
    }

    if(!sd_readsector(4152, buffer, 1)) {
	printf("Could not read sector from SDCard\n");
	return 1;
    }

    for(int i=0; i<128; ++i) {
	print_hex_digits(buffer[i], 2);
	if(!i%16) {
	    printf("\n");
	}
    }
    printf("\n");
*/
    exit(0); // femtOS does not properly exit programs, so exit() is needed (to be fixed)   
}
