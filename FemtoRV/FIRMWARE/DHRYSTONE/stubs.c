long time() 
{
   int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
//   printf("==== CYCLES = %d\n", cycles);
   return cycles;
}

long insn() 
{
   int insns;
   asm volatile ("rdinstret %0" : "=r"(insns));
//   printf("==== INSNS = %d\n", insns);   
   return insns;
}

