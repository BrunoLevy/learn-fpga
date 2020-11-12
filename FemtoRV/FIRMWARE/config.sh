#TOOLCHAIN_DIR=/usr/bin
#RVAS=$TOOLCHAIN_DIR/riscv64-linux-gnu-as
#RVLD=$TOOLCHAIN_DIR/riscv64-linux-gnu-ld
#RVOBJCOPY=$TOOLCHAIN_DIR/riscv64-linux-gnu-objcopy
#RVOBJDUMP=$TOOLCHAIN_DIR/riscv64-linux-gnu-objdump
#RVGCC=$TOOLCHAIN_DIR/riscv64-linux-gnu-gcc-10

TOOLCHAIN_DIR=/home/blevy/Packages/riscv64-unknown-elf-gcc-20171231-x86_64-linux-centos6/bin
RVAS=$TOOLCHAIN_DIR/riscv64-unknown-elf-as
RVLD=$TOOLCHAIN_DIR/riscv64-unknown-elf-ld
RVOBJCOPY=$TOOLCHAIN_DIR/riscv64-unknown-elf-objcopy
RVOBJDUMP=$TOOLCHAIN_DIR/riscv64-unknown-elf-objdump
RVGCC=$TOOLCHAIN_DIR/riscv64-unknown-elf-gcc


# Configuration for the ICEStick
ARCH=rv32i
ABI=ilp32
OPTIMIZE=-Os # This one for the ICEstick (optimize for size, we only have 6K of RAM !)

# Configuration for larger boards (ULX3S, ECPC-EVN)
#ARCH=rv32im
#ABI=ilp32
#OPTIMIZE=-O3 


