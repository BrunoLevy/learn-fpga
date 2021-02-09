include ../makefile.inc

OBJECTS= font_8x16.o font_8x8.o font_5x6.o font_3x5.o \
         femtoGL.o femtoGLtext.o femtoGLfill_rect.o\
	 femtoGLsetpixel.o femtoGLline.o femtoGLfill_poly.o \
	 tty_init.o max7219_text.o \
	 FGA_mode.o FGA.o \
	 femto_GUI.o
	
all: $(RVGCC) libfemtoGL.a

libfemtoGL.a: $(OBJECTS) 
	$(RVAR) cq libfemtoGL.a $(OBJECTS) 
	$(RVRANLIB) libfemtoGL.a

