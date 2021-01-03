/*
 * A dummy IVERILOG module just to get the configured amount of RAM.
 */

`include "femtosoc_config.v"

module print_RAM();
initial begin
   $display("`define NRV_RAM %d",`NRV_RAM);
end

endmodule
