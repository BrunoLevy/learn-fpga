#include <femtorv32.h>
#include <femtoGL.h>

// Demo program for 'make testbench'

// Redirect char output to LED port, 
// bench mode displays LED port content in hex and char format
void bench_putchar(int c) {
   IO_OUT(IO_LEDS,c);
}

int main() {
   set_putcharfunc(bench_putchar);
   printf("Hello world !!\n Let me introduce myself, I am FemtoRV32, one of the smallest RISC-V cores\n");
   return 0;
}


