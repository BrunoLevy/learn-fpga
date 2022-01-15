#include <lite_stdio.h>
#include <libfatfs/ff.h>
#include <libfatfs/diskio.h>

#include <string.h>
#include <stdlib.h>

#include <generated/csr.h>

static int filesystem_init = 0;
#define FILDES_NB 4
static int fildes_used[FILDES_NB] = { -1, -1, -1, -1 };
static FIL fildes[FILDES_NB];
static char* fildes_path[FILDES_NB];

LX_FILE* lx_fopen(const char* pathname, const char* mode) {
    int imode = 0;
    int fd;    
    printf("fopen(%s)\n",pathname);
    if(strchr(mode,'w')) {
	imode = LX_O_WRONLY;
    }
    if(strchr(mode,'r')) {
	imode = LX_O_RDONLY;
    }
    fd = lx_open(pathname, imode);
    if(fd == -1) {
	return NULL;
    }
    return &fildes_used[fd];
}

size_t lx_fread(void *ptr, size_t size, size_t nmemb, LX_FILE *stream) {
   printf("fread\n");
   size_t result = lx_read(*stream, ptr, size*nmemb);
   return (result / size);
}

size_t lx_fwrite(const void *ptr, size_t size, size_t nmemb, LX_FILE *stream) {
   printf("fwrite\n");
   size_t result = lx_write(*stream, ptr, size*nmemb);
   return (result / size);
}

int lx_fclose(LX_FILE* stream) {
   printf("fclose\n");
   lx_close(*stream);
   return 0;
}

int lx_fprintf(LX_FILE* stream, const char *format, ...) {
   printf("fprintf\n");   
   return 0;
}

int lx_fscanf(LX_FILE* stream, const char *format, ...) {
   printf("fscanf\n");
   return 0;
}

int lx_fseek(LX_FILE *stream, long offset, int whence) {
   printf("fseek %d\n",whence);
   return 0;
}

long lx_ftell(LX_FILE *stream) {
   printf("ftell\n");
   return 0;
}

int lx_feof(LX_FILE* stream) {
   printf("feof\n");
   return 0;
}

/*****************************************************************************/

static void lx_mount(void) {
    static FATFS fs;
    if(!filesystem_init) {
	filesystem_init = 1;
	printf("Mounting filesystem\n");
	if(f_mount(&fs,"",1) != FR_OK) {
	    printf("Could not mount filesystem\n");
	}
    }
}

int lx_open(const char *pathname, int flags, ...) {
    int f_flags = 0;
    int i;

    if(*pathname == '.') {
	++pathname;
    }

    if(*pathname == '/') {
	++pathname;
    }

    if(flags & LX_O_RDONLY) {
	f_flags = FA_READ;
    }

    if(flags & LX_O_WRONLY) {
	f_flags = FA_WRITE;
    }
    
    lx_mount();
    printf("open(%s)\n",pathname);
    for(i=0; i<FILDES_NB; ++i) {
	if(fildes_used[i] == -1) {
	    if(f_open(&fildes[i], pathname, f_flags) == FR_OK) {
		fildes_used[i] = i;
		fildes_path[i] = strdup(pathname);
		return i;
	    } else {
		return -1;
	    }
	}
    }
    return -1;
}

ssize_t lx_read(int fd, void *buf, size_t count) {
   UINT res;
// printf("read\n");   
   f_read(&fildes[fd], buf, count, &res);
   return res;
}

ssize_t lx_write(int fd, const void *buf, size_t count) {
   UINT res = 0;
   printf("write\n");
// f_write(&fildes[fd], buf, count, &res);
   return res;
}

int lx_close(int fd) {
//  printf("close\n");
    free(fildes_path[fd]);
    return(f_close(&fildes[fd]) != F_OK);
}

off_t lx_lseek(int fd, off_t offset, int whence) {
//  printf("lseek %d\n",whence);
    f_lseek(&fildes[fd], offset);
    return offset;
}

int lx_fstat(int fd, struct lx_stat *statbuf) {
//  printf("fstat\n");
    return lx_stat(fildes_path[fd],statbuf);
}

int lx_stat(const char *pathname, struct lx_stat *statbuf) {
    FIL fil;
//  FILINFO info;
    lx_mount();

    if(*pathname == '.') {
	++pathname;
    }

    if(*pathname == '/') {
	++pathname;
    }
    
    printf("stat(%s)\n",pathname);
 
    if(f_open(&fil, pathname, FA_READ) == F_OK) {
       f_close(&fil);
       statbuf->st_size = 0;   
       return 0;
   }

   return -1;
}


int lx_gettimeofday(struct lx_timeval *tv, struct lx_timezone *tz) {
   static uint32_t val = 0;
   tv->tv_usec = val;
   tv->tv_sec  = 0;
   val += 100;
   /*
   static int first_time = 1;
   uint32_t ticks;

   if(first_time) {
      timer0_en_write(0);
      timer0_reload_write(0xffffffff);
      timer0_load_write(0xffffffff);
      timer0_en_write(1);
   }
   
   timer0_update_value_write(1);
   ticks = 0xffffffff - timer0_value_read();
   tv->tv_usec = ticks / (CONFIG_CLOCK_FREQUENCY / 1000000);
   tv->tv_sec  = 0;
   */
   return 0;
}


