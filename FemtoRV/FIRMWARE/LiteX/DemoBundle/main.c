// This file is Copyright (c) 2020 Florent Kermarrec <florent@enjoy-digital.fr>
// License: BSD

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <irq.h>
#include <libbase/uart.h>
#include <libbase/console.h>
#include <generated/csr.h>

#include "demos/demos.h"

/*-----------------------------------------------------------------------*/
/* Uart                                                                  */
/*-----------------------------------------------------------------------*/

static char *readstr(void)
{
	char c[2];
	static char s[64];
	static int ptr = 0;

	if(readchar_nonblock()) {
		c[0] = getchar();
		c[1] = 0;
		switch(c[0]) {
			case 0x7f:
			case 0x08:
				if(ptr > 0) {
					ptr--;
					fputs("\x08 \x08", stdout);
				}
				break;
			case 0x07:
				break;
			case '\r':
			case '\n':
				s[ptr] = 0x00;
				fputs("\n", stdout);
				ptr = 0;
				return s;
			default:
				if(ptr >= (sizeof(s) - 1))
					break;
				fputs(c, stdout);
				s[ptr] = c[0];
				ptr++;
				break;
		}
	}

	return NULL;
}

static char *get_token(char **str)
{
	char *c, *d;

	c = (char *)strchr(*str, ' ');
	if(c == NULL) {
		d = *str;
		*str = *str+strlen(*str);
		return d;
	}
	*c = 0;
	d = *str;
	*str = c+1;
	return d;
}

static void prompt(void)
{
	printf("\e[92;1mlitex-demo-bundle\e[0m> ");
}

/*-----------------------------------------------------------------------*/
/* Help                                                                  */
/*-----------------------------------------------------------------------*/

static void help(void)
{
	puts("\nLiteX raytracing benchmark, built "__DATE__" "__TIME__"\n");
	puts("Available commands:");
	puts("help            - Show this command");
	puts("reboot          - Reboot CPU");
	puts("tinyraytracer   - Raytracing demo");
	puts("mandelbrot      - Mandelbrot set");   
	puts("raystones       - Raytracing benchmark");
	puts("pi              - Compute the decimals of pi");
#ifdef CSR_OLED_SPI_BASE
	puts("oled_test       - Displays pattern on OLED screen");
	puts("oled_riscv_logo - Displays rotating RISC-V logo on OLED screen");
	puts("oled_julia      - Displays animated Julia set on OLED screen");   
#endif   
}

/*-----------------------------------------------------------------------*/
/* Commands                                                              */
/*-----------------------------------------------------------------------*/

static void reboot_cmd(void)
{
	ctrl_reset_write(1);
}


/*-----------------------------------------------------------------------*/
/* Console service / Main                                                */
/*-----------------------------------------------------------------------*/

static void console_service(void)
{
	char *str;
	char *token;

	str = readstr();
	if(str == NULL) return;
	token = get_token(&str);
	if(!strcmp(token, "help"))
		help();
	else if(!strcmp(token, "reboot"))
		reboot_cmd();
	else if(!strcmp(token, "tinyraytracer"))
		tinyraytracer(1);
	else if(!strcmp(token, "mandelbrot"))
		mandelbrot();
	else if(!strcmp(token, "raystones"))
		tinyraytracer(0);
	else if(!strcmp(token, "pi"))
		pi();
#ifdef CSR_OLED_SPI_BASE
	else if(!strcmp(token, "oled_test"))
		oled_test();
	else if(!strcmp(token, "oled_riscv_logo"))
		oled_riscv_logo();
	else if(!strcmp(token, "oled_julia"))
		oled_julia();
#endif   
        else if(*token != '\0') puts("Unknown command");
	prompt();
}

int main(void)
{
#ifdef CONFIG_CPU_HAS_INTERRUPT
	irq_setmask(0);
	irq_setie(1);
#endif
	uart_init();

	help();
	prompt();

	while(1) {
		console_service();
	}

	return 0;
}
