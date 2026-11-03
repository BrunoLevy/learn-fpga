#! /usr/bin/env bash

# setup python environment
python3 -m venv .venv
source .venv/bin/activate
pip3 install riscv_isac git+https://github.com/riscv-non-isa/riscv-arch-test/#subdirectory=riscv-isac
pip3 install riscv-config git+https://github.com/riscv-software-src/riscv-config@dev
pip3 install riscof git+https://github.com/riscv-software-src/riscof@dev

# setup tool paths
source ../settings-questa.sh
source ../settings-vivado.sh
export PATH=/opt/riscv-isa-sim/bin/:$PATH
export PATH=/opt/riscv-gcc/bin/:$PATH
export PATH=`git rev-parse --show-toplevel`/submodules/sail-riscv/build/c_emulator/:$PATH

# run tests for mouse/degu
riscof run --config=config-mouse.ini --suite=../submodules/riscv-arch-test/riscv-test-suite/ --env=../submodules/riscv-arch-test/riscv-test-suite/env
riscof run --config=config-degu.ini  --suite=../submodules/riscv-arch-test/riscv-test-suite/ --env=../submodules/riscv-arch-test/riscv-test-suite/env