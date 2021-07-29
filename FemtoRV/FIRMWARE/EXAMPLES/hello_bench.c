#include <femtorv32.h>
#include <femtoGL.h>

// Demo program for 'make testbench'

int main() {
   femtosoc_tty_init();
   printf("Hello world !!\n Let me introduce myself, I am FemtoRV32, one of the smallest RISC-V cores\n");
   putchar(4); // EOT
   return 0;
}


