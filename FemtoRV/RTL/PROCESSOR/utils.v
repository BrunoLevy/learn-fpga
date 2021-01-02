/********************* Utilities, macros for debugging *************/

`ifdef VERBOSE
  `define verbose(command) command
`else
  `define verbose(command)
`endif

`ifdef BENCH
 `define BENCH_OR_LINT
 `ifdef QUIET
  `define bench(command) 
 `else
  `define bench(command) command
 `endif
`else
  `define bench(command)
`endif

`ifdef verilator
 `define BENCH_OR_LINT
`endif
