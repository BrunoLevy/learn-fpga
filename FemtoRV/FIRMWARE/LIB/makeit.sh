# Note: it seems that crt0.o is linked automatically (not added into lib)

SOURCES="femtorv32.s mul.s div.s max2719.s ssd1351.s uart.s print.c printf.c crt0.s"
OBJECTS="femtorv32.o mul.o div.o max2719.o ssd1351.o uart.o print.o printf.o"
echo 'Compiling libfemtorv32'
for i in `echo $SOURCES`
do
   if [[ $i == *.s ]]
   then
      echo '   Compiling asm source:' $i
      riscv64-linux-gnu-as -march=rv32i -mabi=ilp32 $i -o `basename $i .s`.o
   else
      if [[ $i == *.c ]] 
      then
         echo '   Compiling C source:' $i      
         riscv64-linux-gnu-gcc-10 -O3 -fno-pic -march=rv32i -mabi=ilp32 -I. -c $i 
      fi
   fi
done   
rm -f libfemtorv32.a
riscv64-linux-gnu-ar cq libfemtorv32.a $OBJECTS
riscv64-linux-gnu-ranlib libfemtorv32.a



