include ../makefile.inc

FAT_IO_OBJS_WITH_DIR=fat_io_lib/fat_access.o fat_io_lib/fat_cache.o \
                     fat_io_lib/fat_filelib.o fat_io_lib/fat_format.o fat_io_lib/fat_misc.o \
                     fat_io_lib/fat_string.o fat_io_lib/fat_table.o fat_io_lib/fat_write.o

FAT_IO_OBJS=fat_access.o fat_cache.o fat_filelib.o fat_format.o fat_misc.o \
            fat_string.o fat_table.o fat_write.o

OBJECTS= femtorv32.o max7219.o ssd1351_1331.o ssd1351_1331_init.o uart.o keyboard.o \
         virtual_io.o \
	 wait_cycles.o microwait.o milliwait.o milliseconds.o\
         spi_sd.o cycles_32.o cycles_64.o \
	 filesystem.o exec.o femto_elf.o 

all: $(RVGCC) libfemtorv32.a 

libfemtorv32.a: $(OBJECTS) $(FAT_IO_OBJS_WITH_DIR) 
	$(RVAR) cq libfemtorv32.a $(OBJECTS) $(FAT_IO_OBJS)
	$(RVRANLIB) libfemtorv32.a

