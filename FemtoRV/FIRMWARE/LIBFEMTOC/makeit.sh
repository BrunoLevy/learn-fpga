# Note: it seems that crt0.o is linked automatically (not added into lib)

. ../config.sh

#Uncomment if your riscv-gcc does not have a bundled libc/libgcc

#MISSING_LIBC_SOURCES="missing/mul.S missing/div.S \
#                      missing/memset.c missing/memcpy.c missing/random.c missing/strcpy.c missing/strncpy.c missing/strcmp.c missing/strncmp.c missing/strlen.c\
#                      missing/clz.c"

#MISSING_LIBC_OBJECTS="mul.o div.o print.o printf.o \
#                      memset.o memcpy.o random.o strcpy.o strncpy.o strcmp.o strncmp.o strlen.o\
#                      clz.o"

SOURCES="print.c printf.c $MISSING_LIBC_SOURCES"
OBJECTS="print.o printf.o $MISSING_LIBC_OBJECTS"


echo 'Compiling libfemtoc'
for i in `echo $SOURCES`
do
   if [[ $i == *.S ]]
   then
      echo '   Compiling asm source:' $i
      $RVAS -march=$ARCH -mabi=$ABI $i -I../LIBFEMTORV32 -o `basename $i .S`.o
   else
      if [[ $i == *.c ]] 
      then
         echo '   Compiling C source:' $i      
         $RVGCC -w $OPTIMIZE -D_LIBC -Isysdeps/riscv/ -I. -I../LIBFEMTORV32 -fno-pic -march=$ARCH -mabi=$ABI -I. -fno-stack-protector -c $i
      fi
   fi
done   
rm -f libfemtoc.a
riscv64-linux-gnu-ar cq libfemtoc.a $OBJECTS
riscv64-linux-gnu-ranlib libfemtoc.a



