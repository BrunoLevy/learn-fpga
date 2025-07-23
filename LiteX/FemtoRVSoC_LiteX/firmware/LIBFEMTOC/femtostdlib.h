#ifndef H__FEMTOSTDLIB__H
#define H__FEMTOSTDLIB__H

#include <femtorv32.h>

/* My light weight replacement function for printf() */
extern int printf(const char *fmt,...); /* supports %s, %d, %x */

/* Uncomment if using functions in 'missing' subdirectory
void* memset(void *s, int c, size_t n);
void* memcpy(void *dest, const void *src, size_t n);
char* strcpy(char *dest, const char *src);
char* strncpy(char *dest, const char *src, size_t n);
int   strcmp(const char *p1, const char *p2);
size_t strlen(const char* p);
extern int random();
*/

/* Specialized print functions (but one can use printf() instead) */
extern void print_string(const char* s);
extern void print_dec(int val);
extern void print_hex_digits(unsigned int val, int digits);
extern void print_hex(unsigned int val);

#endif
