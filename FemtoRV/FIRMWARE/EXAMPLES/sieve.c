// Taken from picorv32
// 
// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

// A simple Sieve of Eratosthenes

#include <femtorv32.h>

// Note: if this is changed, then checksum need 
// to be updated as well.
#define BITMAP_SIZE 64

typedef int bool;

static uint32_t bitmap[BITMAP_SIZE/32];

static uint32_t hash;

static uint32_t mkhash(uint32_t a, uint32_t b)
{
	// The XOR version of DJB2
	return ((a << 5) + a) ^ b;
}

static void bitmap_set(int idx)
{
   bitmap[idx/32] |= 1 << (idx % 32);
}

static bool bitmap_get(int idx)
{
   return (bitmap[idx/32] & (1 << (idx % 32))) != 0;
}

static void print_prime(int idx, int val)
{
	if (idx < 10)
		printf(" ");
	printf("%d",idx);

	if (idx / 10 == 1)
		goto force_th;
	switch (idx % 10) {
		case 1: printf("st"); break;
		case 2: printf("nd"); break;
		case 3: printf("rd"); break;
	force_th:
		default: printf("th"); break;
	}
	printf(" prime: %d\n",val);

	hash = mkhash(hash, idx);
	hash = mkhash(hash, val);
}

int main(void)
{
       /*
	* redirects display to UART (default), OLED display
	* or led matrix, based on configured devices (in femtosoc.v).
	* Note: pulls the two fonts (eats up a subsequent part of the
	* available 6 Kbs).
	*   To save code size, on the IceStick, you can use 
	* instead MAX7219_tty_init() if you know you are 
	* using the led matrix, or GL_tty_init() if you know you are 
	* using the small OLED display.
	*/
        femtosoc_tty_init();

	int idx;

start:
	idx = 1;
	hash = 5381;
	print_prime(idx++, 2);
	for (int i = 0; i < BITMAP_SIZE; i++) {
		if (bitmap_get(i))
			continue;
		print_prime(idx++, 3+2*i);
		delay(25); /* wait 25ms, so that we can see the 
			    * OLED screen scrolling (else it is too fast).
			    */
		for (int j = 2*(3+2*i);; j += 3+2*i) {
			if (j%2 == 0)
				continue;
			int k = (j-3)/2;
			if (k >= BITMAP_SIZE)
				break;
			bitmap_set(k);
		}
	}

	printf("checksum:\n   %x",hash);

	if (hash == 0x1772A48F) {
	        printf(" OK\n");
	} else {
		printf(" ERROR\n");
	}

   delay(1000);
   goto start;  // loop forever

   return 0;
}

