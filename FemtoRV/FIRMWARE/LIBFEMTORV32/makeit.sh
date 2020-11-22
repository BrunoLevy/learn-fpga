# Note: it seems that crt0.o is linked automatically (not added into lib)

. ../config.sh

FAT_IO_SRC="fat_io_lib/fat_access.c fat_io_lib/fat_cache.c fat_io_lib/fat_filelib.c \
            fat_io_lib/fat_format.c fat_io_lib/fat_misc.c fat_io_lib/fat_string.c \
            fat_io_lib/fat_table.c fat_io_lib/fat_write.c"

FAT_IO_OBJS="fat_access.o fat_cache.o fat_filelib.o fat_format.o fat_misc.o \
             fat_string.o fat_table.o fat_write.o"


SOURCES="femtorv32.S microwait.S max2719.S ssd1351.S uart.S \
         font_8x8.S font_5x6.S font_3x5.S virtual_io.c femtoGL.c femtoGLtext.c \
	 femtoGLsetpixel.c femtoGLline.c femtoGLfill_poly.c \
	 tty_init.c max2719_text.c \
	 $FAT_IO_SRC \
         spi_sd.c exec.c \
         cycles.S \
	 crt0.S"

OBJECTS="femtorv32.o microwait.o max2719.o ssd1351.o uart.o \
         font_8x8.o font_5x6.o font_3x5.o virtual_io.o femtoGL.o femtoGLtext.o \
	 femtoGLsetpixel.o femtoGLline.o femtoGLfill_poly.o \
	 tty_init.o max2719_text.o \
	 $FAT_IO_OBJS \
         spi_sd.o exec.o \
         cycles.o"

echo 'Compiling libfemtorv32'
for i in `echo $SOURCES`
do
   if [[ $i == *.S ]]
   then
      echo '   Compiling asm source:' $i
      $RVAS -march=$ARCH -mabi=$ABI $i -o `basename $i .S`.o
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



