# Note: it seems that crt0.o is linked automatically (not added into lib)

. ../config.sh

FAT_IO_SRC="fat_io_lib/fat_access.c fat_io_lib/fat_cache.c fat_io_lib/fat_filelib.c \
            fat_io_lib/fat_format.c fat_io_lib/fat_misc.c fat_io_lib/fat_string.c \
            fat_io_lib/fat_table.c fat_io_lib/fat_write.c"

FAT_IO_OBJS="fat_access.o fat_cache.o fat_filelib.o fat_format.o fat_misc.o \
             fat_string.o fat_table.o fat_write.o"


SOURCES="femtorv32.s microwait.s mul.s div.s max2719.s ssd1351.s uart.s print.c printf.c \
         font_8x8.s font_5x6.s font_3x5.s virtual_io.c femtoGL.c femtoGLtext.c \
	 femtoGLsetpixel.c femtoGLline.c femtoGLfill_poly.c \
         memset.c memcpy.c random.c strcpy.c strncpy.c strcmp.c strncmp.c strlen.c\
	 tty_init.c max2719_text.c \
	 clz.c \
	 $FAT_IO_SRC \
         spi_sd.c exec.c \
         cycles.s \
	 crt0.s"

OBJECTS="femtorv32.o microwait.o mul.o div.o max2719.o ssd1351.o uart.o print.o printf.o \
         font_8x8.o font_5x6.o font_3x5.o virtual_io.o femtoGL.o femtoGLtext.o \
	 femtoGLsetpixel.o femtoGLline.o femtoGLfill_poly.o \
         memset.o memcpy.o random.o strcpy.o strncpy.o strcmp.o strncmp.o strlen.o\
	 tty_init.o max2719_text.o \
	 clz.o \
	 $FAT_IO_OBJS \
         spi_sd.o exec.o \
         cycles.o"

echo 'Compiling libfemtorv32'
for i in `echo $SOURCES`
do
   if [[ $i == *.s ]]
   then
      echo '   Compiling asm source:' $i
      $RVAS -march=$ARCH -mabi=$ABI $i -o `basename $i .s`.o
   else
      if [[ $i == *.c ]] 
      then
         echo '   Compiling C source:' $i      
         $RVGCC -w $OPTIMIZE -D_LIBC -Isysdeps/riscv/ -I. -fno-pic -march=$ARCH -mabi=$ABI -I. -fno-stack-protector -c $i
      fi
   fi
done   
rm -f libfemtorv32.a
riscv64-linux-gnu-ar cq libfemtorv32.a $OBJECTS 
riscv64-linux-gnu-ranlib libfemtorv32.a



