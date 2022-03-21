rm -f a.out
iverilog -DSIM bench_iverilog.v $1
vvp a.out
