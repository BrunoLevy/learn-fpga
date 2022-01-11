#ifndef LITE_STDIO
#define LITE_STDIO

#include <stdarg.h>

/**
 * Wrappers for emulating stdio functions
 * using LiteX fatfs functions.
 * Disclaimer: the bare minimal to make Doom work,
 * not everything is implemented, use at your own
 * risk !
 * Bruno Levy, 2022.
 */ 


#ifdef LX_STDIO_OVERRIDE

#ifdef _STDIO_H_
#error "lite_stdio.h needs to be included before stdio.h"
#endif

#define _STDIO_H_ 1

# define FILE LX_FILE
#define fopen lx_fopen
#define fread lx_fread
#define fwrite lx_fwrite
#define fclose lx_fclose
#define fprintf lx_fprintf
#define fscanf lx_fscanf
#define feof lx_feof

#define open  lx_open
#define read  lx_read
#define write lx_write
#define close lx_close
#define lseek lx_lseek
#define fseek lx_fseek
#define ftell lx_ftell
#define fstat lx_fstat
#define stat lx_stat

#define O_RDONLY 1
#define O_WRONLY 2
#define O_CREAT  4
#define O_TRUNC  8
#define O_BINARY 16

#define timeval      lx_timeval
#define timezone     lx_timezone
#define gettimeofday lx_gettimeofday
#endif

#include <stddef.h>
#include <stdint.h>
#include <unistd.h>

typedef int LX_FILE; 

struct lx_stat {
   size_t st_size;
};

struct lx_timeval {
   time_t      tv_sec;   
   suseconds_t tv_usec;  
};

struct lx_timezone {
   int tz_minuteswest;     /* minutes west of Greenwich */
   int tz_dsttime;         /* type of DST correction */
};

#define LX_O_RDONLY 1
#define LX_O_WRONLY 2
#define LX_O_CREAT  4
#define LX_O_TRUNC  8
#define LX_O_BINARY 16


LX_FILE* lx_fopen(const char* pathname, const char* mode);
size_t   lx_fread(void *ptr, size_t size, size_t nmemb, LX_FILE *stream);
size_t   lx_fwrite(const void *ptr, size_t size, size_t nmemb, LX_FILE *stream);
int      lx_fclose(LX_FILE* stream);
int      lx_fseek(LX_FILE *stream, long offset, int whence);
long     lx_ftell(LX_FILE *stream);
int      lx_fprintf(LX_FILE* stream, const char *format, ...);
int      lx_fscanf(LX_FILE* stream, const char *format, ...);
int      lx_feof(LX_FILE* stream);

int      lx_open(const char *pathname, int flags, ...);
ssize_t  lx_read(int fd, void *buf, size_t count);
ssize_t  lx_write(int fd, const void *buf, size_t count);
int      lx_close(int fd);
off_t    lx_lseek(int fd, off_t offset, int whence);
int      lx_fstat(int fd, struct lx_stat *statbuf);
int      lx_stat(const char *pathname, struct lx_stat *statbuf);

int      lx_gettimeofday(struct lx_timeval *tv, struct lx_timezone *tz);

int getchar(void);
int printf(const char *format, ...);
int sprintf(char *str, const char *format, ...);
int vprintf(const char *format, va_list ap);

int scanf(const char *format, ...);
int sscanf(const char* str, const char *format, ...);

#endif
