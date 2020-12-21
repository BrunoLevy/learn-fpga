#include <femtorv32.h>

/************************************************************************/

/* 
 * Executes a flat binary file. Data is to be implanted at address 0x10000.
 * crt is starting from address 0x10074 (readelf -a shows that).
 */
int exec(const char* filename) {

    if(sd_init()) {
	printf("Could not initialize SDCard\n");
	return -1;
    }
    printf("SDCard OK\n");
    fl_init();
    if(fl_attach_media(
	   (fn_diskio_read)sd_readsector,
	   (fn_diskio_write)sd_writesector) != FAT_INIT_OK
    ) {
	printf("ERROR: Failed to init file system\n");
	return -1;
    }
    printf("FileSystem OK\n");

    FILE* f = fopen(filename,"r");
    if(!f) {
	printf("Could not open %s\n", filename);
	return -1;
    }
    fseek(f, 0, SEEK_END);
    int file_size = ftell(f);
    printf("File size = %d\n", file_size);
    fseek(f, 0, SEEK_SET);

    void* start = (void*)0x10000;
    int memsize = IO_IN(IO_RAM);
    memset(start, 0, memsize - 0x10000 - 1024); // -1024 to avoid touching the stack
    
    if(fread(start, 1, file_size, f) != file_size) {
      	printf("Error while reading file\n");
    } else {
	printf("File ready in RAM\n");
    }

    asm("j 0x10074"); // TODO: understand why it starts 74 bites away from 0x10000
                      // NOTE: programs that simply return from main() are looping,
                      // I do not know why (to be fixed)
    
    return 0;
}
