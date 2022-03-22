rm -f a.out
iverilog -DBENCH -DSIM bench_iverilog.v $1
vvp a.out
