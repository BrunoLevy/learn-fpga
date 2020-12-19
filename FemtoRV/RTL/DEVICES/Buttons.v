// femtorv32, a minimalistic RISC-V RV32I core
//       Bruno Levy, 2020-2021
//
// This file: driver for the buttons (does nearly nothing,
// could include some filtering here).

module Buttons(
    input wire 	       sel,   // select (read/write ignored if low)
    output wire [31:0] rdata, // read data

    input wire[5:0]   BUTTONS // the six pins wired to the buttons
);

   assign rdata = (sel ? {27'b0, BUTTONS} : 32'b0);

endmodule
