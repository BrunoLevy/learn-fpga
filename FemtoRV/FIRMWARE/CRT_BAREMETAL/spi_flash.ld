
MEMORY
{
   rom(RX)   : ORIGIN = 0x00800000, LENGTH = 0x400
}
   
SECTIONS
{
  .text : { *(.text*) } > rom
}

      
      