riscv64-linux-gnu-as -march=rv32i -mabi=ilp32 -o femtorv32.o femtorv32.s
riscv64-linux-gnu-as -march=rv32i -mabi=ilp32 -o crt0.o crt0.S
riscv64-linux-gnu-ar cq libfemtorv32.a crt0.o femtorv32.o
riscv64-linux-gnu-ranlib libfemtorv32.a



