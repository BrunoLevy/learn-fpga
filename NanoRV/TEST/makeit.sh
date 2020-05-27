#verilator -cc --top-module ALU_bench ../nanorv.v bench.v
(cd ../FIRMWARE; ./makeit.sh)
rm -f bench
iverilog bench.v -o bench
vvp bench
