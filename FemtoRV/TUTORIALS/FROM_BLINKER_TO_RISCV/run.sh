rm -f a.out
iverilog bench_iverilog.v $1
vvp a.out
