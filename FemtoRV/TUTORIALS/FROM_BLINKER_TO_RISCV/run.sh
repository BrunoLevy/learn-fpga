rm -f a.out
iverilog $1
vvp a.out
