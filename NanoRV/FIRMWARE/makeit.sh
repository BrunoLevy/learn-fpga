PROGNAME=firmware

riscv64-linux-gnu-as -o $PROGNAME.o $PROGNAME.s 
riscv64-linux-gnu-ld -Ttext 0 -o $PROGNAME.elf $PROGNAME.o
riscv64-linux-gnu-objcopy -O binary $PROGNAME.elf $PROGNAME.bin
riscv64-linux-gnu-objdump -D -b binary -m riscv $PROGNAME.bin


riscv64-linux-gnu-objdump -D -b binary -m riscv $PROGNAME.bin | awk '{
   if($1 == "0000000000000000") {
      state=1;
   } else {
      if(state) {
         print $2;
      }
   }
}' > $PROGNAME.hex
echo 00000000 >> $PROGNAME.hex

#echo
#echo '***** generated ROM content ****'
#echo
echo ROM size: `cat $PROGNAME.hex | wc -l` words



