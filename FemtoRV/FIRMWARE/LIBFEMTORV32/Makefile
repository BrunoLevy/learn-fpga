
FAT_IO_SRC=fat_io_lib/fat_access.c fat_io_lib/fat_cache.c fat_io_lib/fat_filelib.c \
            fat_io_lib/fat_format.c fat_io_lib/fat_misc.c fat_io_lib/fat_string.c \
            fat_io_lib/fat_table.c fat_io_lib/fat_write.c

FAT_IO_OBJS_WITH_DIR=fat_io_lib/fat_access.o fat_io_lib/fat_cache.o \
                     fat_io_lib/fat_filelib.o fat_io_lib/fat_format.o fat_io_lib/fat_misc.o \
                     fat_io_lib/fat_string.o fat_io_lib/fat_table.o fat_io_lib/fat_write.o

FAT_IO_OBJS=fat_access.o fat_cache.o fat_filelib.o fat_format.o fat_misc.o \
            fat_string.o fat_table.o fat_write.o

OBJECTS=femtorv32.o microwait.o max2719.o ssd1351.o uart.o \
         font_8x8.o font_5x6.o font_3x5.o virtual_io.o femtoGL.o femtoGLtext.o \
	 femtoGLsetpixel.o femtoGLline.o femtoGLfill_poly.o \
	 tty_init.o max2719_text.o \
         spi_sd.o exec.o \
         cycles.o

all: libfemtorv32.a

libfemtorv32.a: $(OBJECTS) $(FAT_IO_OBJS_WITH_DIR) crt0.o
	$(RVAR) cq libfemtorv32.a $(OBJECTS) $(FAT_IO_OBJS)
	$(RVRANLIB) libfemtorv32.a

include ../makefile.inc
