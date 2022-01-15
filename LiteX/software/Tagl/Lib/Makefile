
OPTIMIZE= -O6 -DGINT -fomit-frame-pointer -funroll-loops -DNDEBUG
CCX11=-I/usr/X11R6/include -DX_SHM 
CXXOPT= -fpermissive -Wno-deprecated $(OPTIMIZE) $(CCX11)

SRC= Xgport.cc\
  Xpeng.cc\
  dldlinker.cc\
  gcomp.cc\
  gman.cc\
  gport.cc\
  gproc.cc\
  locgman.cc\
  peng_24.cc\
  peng_32x.cc\
  peng_32xi.cc\
  peng_555.cc\
  peng_565.cc\
  peng_8.cc\
  peng_x32.cc\
  polyeng.cc\
  sintab.cc\
  LinG.cc

OBJS= Xgport.o\
  Xpeng.o\
  dldlinker.o\
  gcomp.o\
  gman.o\
  gport.o\
  gproc.o\
  locgman.o\
  peng_24.o\
  peng_32x.o\
  peng_32xi.o\
  peng_555.o\
  peng_565.o\
  peng_8.o\
  peng_x32.o\
  polyeng.o\
  sintab.o\
  LinG.o

libtagl.a: $(OBJS)
	rm -f libtagl.a 
	ar cq libtagl.a $(OBJS)
	ranlib libtagl.a

.cc.o: $<
	$(CXX) $(CXXOPT) -c $<

       



