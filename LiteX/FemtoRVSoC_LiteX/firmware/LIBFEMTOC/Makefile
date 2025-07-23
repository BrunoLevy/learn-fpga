#Uncomment if not linking with riscv-gcc's libraries
#
#MISSING_OBJECTS=missing/mul.o missing/div.o \
#                memset.o memcpy.o random.o \
#                strcpy.o strncpy.o strcmp.o strncmp.o strlen.o\
#                clz.o
#
#MISSING_OBJECTS_WITH_DIR=missing/mul.o missing/div.o \
#                         missing/memset.o missing/memcpy.o missing/random.o \
#                         missing/strcpy.o missing/strncpy.o missing/strcmp.o missing/strncmp.o \
#                         missing/strlen.o missing/clz.o

OBJECTS=print.o printf.o 

all: $(RVGCC) libfemtoc.a 

libfemtoc.a: $(OBJECTS) $(MISSING_OBJECTS_WITH_DIR) 
	$(RVAR) cq libfemtoc.a $(OBJECTS) $(MISSING_OBJECTS)
	$(RVRANLIB) libfemtoc.a

include ../makefile.inc

