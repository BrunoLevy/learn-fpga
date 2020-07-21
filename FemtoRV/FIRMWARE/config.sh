# Configuration for the ICEStick
#ARCH=rv32i
#ABI=ilp32
#OPTIMIZE=-Os # This one for the ICEstick (optimize for size, we only have 6K of RAM !)

# Configuration for larger boards (ULX3S, ECPC-EVN)
ARCH=rv32im
ABI=ilp32
OPTIMIZE=-O3 


