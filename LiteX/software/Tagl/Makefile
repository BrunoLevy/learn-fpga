include ../makefile.inc

# Include path 
CFLAGS:=$(CFLAGS) -ILib 
CXXFLAGS:=$(CXXFLAGS) -ILib 

all: rotate.elf

ROTATE_OBJECTS= bezier.o cmdline.o gobj.o mesh.o rotate.o smmesh.o smtri.o texture.o trimesh.o

rotate.elf: $(ROTATE_OBJECTS) libtagl.a libliteos.a crt0.o sbrk.o
	$(CC) ./crt0.o $(ROTATE_OBJECTS) sbrk.o $(LDFLAGS) \
		-T linker.ld \
		-N -o $@ \
		$(PACKAGES:%=-L$(BUILD_DIR)/software/%) \
		-L. -ltagl -lliteos $(LIBS:lib%=-l%) -lbase 
	chmod -x $@

LIBTAGL_OBJECTS=gcomp.o gman.o gport.o gproc.o locgman.o peng_x32.o polyeng.o sintab.o LiteXgport.o

libtagl.a: $(LIBTAGL_OBJECTS)
	ar cq libtagl.a $(LIBTAGL_OBJECTS)
	ranlib libtagl.a

%.o: Lib/%.cc
	$(compilexx)

%.o: Rotate/%.cc
	$(compilexx)
