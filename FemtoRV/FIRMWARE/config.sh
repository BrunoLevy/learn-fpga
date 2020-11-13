# Configuration file for firmware compilation
# Specify toolchain and target architecture
#
# ADDITIONAL_LIB points to the target architecture's libgcc, and is used
#  to get the floating point routines. 


# Toolchain installed using debian package gcc-riscv64-unknown-elf
#TOOLCHAIN_DIR=/usr/bin
#RVAS=$TOOLCHAIN_DIR/riscv64-unknown-elf-as
#RVLD=$TOOLCHAIN_DIR/riscv64-unknown-elf-ld
#RVOBJCOPY=$TOOLCHAIN_DIR/riscv64-unknown-elf-objcopy
#RVOBJDUMP=$TOOLCHAIN_DIR/riscv64-unknown-elf-objdump
#RVGCC=$TOOLCHAIN_DIR/riscv64-unknown-elf-gcc
#ADDITIONAL_LIB=/usr/lib/gcc/riscv64-unknown-elf/9.3.0/rv32im/ilp32/libgcc.a

# Toolchain installed from https://static.dev.sifive.com/dev-tools/riscv64-unknown-elf-gcc-20171231-x86_64-linux-centos6.tar.gz
TOOLCHAIN_DIR=/home/blevy/Packages/riscv64-unknown-elf-gcc-20171231-x86_64-linux-centos6/bin
RVAS=$TOOLCHAIN_DIR/riscv64-unknown-elf-as
RVLD=$TOOLCHAIN_DIR/riscv64-unknown-elf-ld
RVOBJCOPY=$TOOLCHAIN_DIR/riscv64-unknown-elf-objcopy
RVOBJDUMP=$TOOLCHAIN_DIR/riscv64-unknown-elf-objdump
RVGCC=$TOOLCHAIN_DIR/riscv64-unknown-elf-gcc
ADDITIONAL_LIB="$TOOLCHAIN_DIR/../riscv64-unknown-elf/lib/rv32im/ilp32/libm.a $TOOLCHAIN_DIR/../lib/gcc/riscv64-unknown-elf/7.2.0/rv32im/ilp32/libgcc.a"

# Configuration for the ICEStick
#ARCH=rv32i
#ABI=ilp32
#OPTIMIZE=-Os # This one for the ICEstick (optimize for size, we only have 6K of RAM !)

# Configuration for larger boards (ULX3S, ECPC-EVN)
ARCH=rv32im
ABI=ilp32
OPTIMIZE=-O3


