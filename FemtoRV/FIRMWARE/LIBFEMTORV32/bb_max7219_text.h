#ifndef _BB_MAX7219_TEXT_H__
#define _BB_MAX7219_TEXT_H__
#include <femtorv32.h>
#include <femtoGL.h>

void BB_MAX7219_shift();
int BB_MAX7219_putchar(int c);
void BB_MAX7219_tty_init();
#endif
