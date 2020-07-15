# Note: it seems that crt0.o is linked automatically (not added into lib)

ARCH=rv32i
ABI=ilp32
OPTIMIZE=-Os

SINGLE_SRC="soft-fp/negsf2.c soft-fp/addsf3.c soft-fp/subsf3.c soft-fp/mulsf3.c soft-fp/divsf3.c soft-fp/eqsf2.c \
	soft-fp/lesf2.c soft-fp/gesf2.c soft-fp/unordsf2.c soft-fp/fixsfsi.c soft-fp/fixunssfsi.c soft-fp/floatsisf.c soft-fp/fixsfdi.c \
	soft-fp/fixunssfdi.c soft-fp/floatdisf.c soft-fp/floatunsisf.c soft-fp/floatundisf.c"

DOUBLE_SRC="soft-fp/negdf2.c soft-fp/adddf3.c soft-fp/subdf3.c soft-fp/muldf3.c soft-fp/divdf3.c soft-fp/eqdf2.c \
	soft-fp/ledf2.c soft-fp/gedf2.c soft-fp/unorddf2.c soft-fp/fixdfsi.c soft-fp/fixunsdfsi.c soft-fp/floatsidf.c soft-fp/fixdfdi.c \
	soft-fp/fixunsdfdi.c soft-fp/floatdidf.c soft-fp/extendsfdf2.c soft-fp/truncdfsf2.c soft-fp/floatunsidf.c \
	soft-fp/floatundidf.c"

SINGLE_OBJS="negsf2.o addsf3.o subsf3.o mulsf3.o divsf3.o eqsf2.o \
	lesf2.o gesf2.o unordsf2.o fixsfsi.o fixunssfsi.o floatsisf.o fixsfdi.o \
	fixunssfdi.o floatdisf.o floatunsisf.o floatundisf.o"

DOUBLE_OBJS="negdf2.o adddf3.o subdf3.o muldf3.o divdf3.o eqdf2.o \
	ledf2.o gedf2.o unorddf2.o fixdfsi.o fixunsdfsi.o floatsidf.o fixdfdi.o \
	fixunsdfdi.o floatdidf.o extendsfdf2.o truncdfsf2.o floatunsidf.o \
	floatundidf.o"


SOURCES="femtorv32.s mul.s div.s max2719.s ssd1351.s uart.s print.c printf.c \
         font_8x8.s font_5x6.s font_3x5.s virtual_io.c femtoGL.c femtoGLtext.c \
	 femtoGLsetpixel.c femtoGLline.c femtoGLfill_poly.c \
         memset.c memcpy.c random.c strcpy.c strncpy.c strcmp.c\
	 tty_init.c max2719_text.c \
	 clz.c \
         $SINGLE_SRC $DOUBLE_SRC \
	 crt0.s"

OBJECTS="femtorv32.o mul.o div.o max2719.o ssd1351.o uart.o print.o printf.o \
         font_8x8.o font_5x6.o font_3x5.o virtual_io.o femtoGL.o femtoGLtext.o \
	 femtoGLsetpixel.o femtoGLline.o femtoGLfill_poly.o \
         memset.o memcpy.o random.o strcpy.o strncpy.o strcmp.o\
	 tty_init.o max2719_text.o\
	 clz.o \
         $SINGLE_OBJS $DOUBLE_OBJS"

echo 'Compiling libfemtorv32'
for i in `echo $SOURCES`
do
   if [[ $i == *.s ]]
   then
      echo '   Compiling asm source:' $i
      riscv64-linux-gnu-as -march=$ARCH -mabi=$ABI $i -o `basename $i .s`.o
   else
      if [[ $i == *.c ]] 
      then
         echo '   Compiling C source:' $i      
         riscv64-linux-gnu-gcc-10 -w $OPTIMIZE -D_LIBC -Isysdeps/riscv/ -I. -fno-pic -march=$ARCH -mabi=$ABI -I. -c $i 
      fi
   fi
done   
rm -f libfemtorv32.a
riscv64-linux-gnu-ar cq libfemtorv32.a $OBJECTS 
riscv64-linux-gnu-ranlib libfemtorv32.a



