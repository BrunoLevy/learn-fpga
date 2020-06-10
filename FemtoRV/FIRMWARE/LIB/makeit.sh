# Note: it seems that crt0.o is linked automatically (not added into lib)

SOURCES="femtorv32.s max2719.s ssd1351.s uart.s crt0.s"
OBJECTS="femtorv32.o max2719.o ssd1351.o uart.o"
for i in `echo $SOURCES`
do
   riscv64-linux-gnu-as -march=rv32i -mabi=ilp32 $i -o `basename $i .s`.o
done   
rm -f libfemtorv32.a
riscv64-linux-gnu-ar cq libfemtorv32.a $OBJECTS
riscv64-linux-gnu-ranlib libfemtorv32.a



