# Python virtual environment
python3 -m venv .venv
source .venv/bin/activate

# GCC for RISC-V
# versions with bug (producing C instructions for -march=rv32i)
#curl -L -O https://github.com/riscv-collab/riscv-gnu-toolchain/releases/latest/download/riscv32-elf-ubuntu-24.04-gcc.tar.xz
#curl -L -O https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2025.12.18/riscv32-elf-ubuntu-24.04-gcc.tar.xz
#curl -L -O https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2025.05.01/riscv32-elf-ubuntu-24.04-gcc-nightly-2025.05.01-nightly.tar.xz
# last prebuilt working version
curl -L -O https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2025.01.20/riscv32-elf-ubuntu-24.04-gcc-nightly-2025.01.20-nightly.tar.xz
rm -rf riscv
tar -xf riscv32-elf-ubuntu-24.04-gcc.tar.xz
export PATH=`pwd`/riscv/bin:$PATH

# Sail simulator for RISC-V
curl -L -O https://github.com/riscv/sail-riscv/releases/download/0.9/sail-riscv-Linux-x86_64.tar.gz
tar -xzf sail-riscv-Linux-x86_64.tar.gz
export PATH=`pwd`/sail-riscv-Linux-x86_64/bin:$PATH

# RISC-V Architecture Test SIG
curl -L -J -O https://github.com/riscv-non-isa/riscv-arch-test/archive/refs/tags/3.10.0.tar.gz
tar -xzf riscv-arch-test-3.10.0.tar.gz

# Python dependencies
pip3 install git+https://github.com/riscv/riscof.git@d38859f85fe407bcacddd2efcd355ada4683aee4
#git submodule add https://github.com/riscv/riscof.git
#cd riscof
#git checkout d38859f
#cd ..
#pip3 install --editable riscof

#riscof run --config=config-quark.ini --suite=riscv-arch-test-3.10.0/riscv-test-suite/ --env=riscv-arch-test-3.10.0/riscv-test-suite/env