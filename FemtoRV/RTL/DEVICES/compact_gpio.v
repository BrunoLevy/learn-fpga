/*maximum of 8 GPIO pins minimum of 2 GPIO pins*/
/*e.g. if you have one pmod and use the oled there are 3 spare pins
one can drive the ledmatrix via bitbang
alternatively leave one pmod pin unallocated and have bitbang i2c
example code provided for bitbang spi and bitbang i2c master*/

//having fixed pins for UEXT complicates things interms of gpio assignment
//might offer a tool to gen pcf and GPIO assignment c header if this gets 
//adpoted

//currently there is a bitbang max7219 linked into the femtorv32 library
//allows for oled and bitbang max7219 on ST_CCC example

//ideally would add optional linking of bitbang drivers
//e.g. in LUT constrained environmenmrnt like ICE40HX1K if using bb_i2c and
//bb_sdcard (not written yet but trivial) one would have to turn off 
//the SSD1351 to get more LUTS but you could then have a gpio button as well
//rather than using the BUTTONS verilog which expects more buttons
//I have a roughed out i2c oled usage demo program. I would like feedback
//on whether compact_gpio.v might be adopted before working on it further
//interms of gpio mapping stratergy and optional linking and bitbang i2c oled
//printf redirect 

module compact_gpio_controller #(
   parameter pin_bits = `NRV_IO_GPIOS_WIDTH
) 
(
    input wire clk,
    input wire rstn,
    input wire sel,
    input wire gpio_rd,
    input wire gpio_wr,
    input wire [31:0] gpio_wdat,
    output wire [31:0] gpio_rdat,
    inout wire [`NRV_IO_GPIOS_WIDTH-1:0] gpio_pin_val
);

    parameter pad_bits = 8 - pin_bits;

    wire [`NRV_IO_GPIOS_WIDTH-1:0]  gpio_pin_do;
    reg [`NRV_IO_GPIOS_WIDTH-1:0]  gpio_pin_level;
    reg [`NRV_IO_GPIOS_WIDTH-1:0]  gpio_dir_ctrl;

/*    
    generate
       if (pin_bits != 8) begin : gen_case_other 
          assign gpio_rdat =  (gpio_rd && sel) ? 
          { {pad_bits'b0},gpio_pin_level,
            {pad_bits'b0},gpio_dir_ctrl,
            {pad_bits'b0},gpio_pin_val, 
            {pad_bits'b0},gpio_pin_do }
            : {32'b0};

       end
       else if (pin_bits == 8) begin : gen_case_8
          assign gpio_rdat =  (gpio_rd && sel) ? 
          {  gpio_pin_level,
             gpio_dir_ctrl,
             gpio_pin_val,
             gpio_pin_do }
            : {32'b0};
       end 
    endgenerate
*/

    generate
       if (pin_bits != 8) begin : gen_case_other 
          assign gpio_rdat =  (gpio_rd && sel) ? 
             { {24'b0},{pad_bits'b0},gpio_pin_do } : {32'b0};
       end
       else if (pin_bits == 8) begin : gen_case_8
          assign gpio_rdat =  (gpio_rd && sel) ? 
             {  {24'b0},gpio_pin_do } : {32'b0};
       end 
    endgenerate

   genvar pin_idx;
    generate
        for (pin_idx=0; pin_idx<`NRV_IO_GPIOS_WIDTH; pin_idx=(pin_idx+1)) begin
            assign gpio_pin_val[pin_idx] = gpio_dir_ctrl[pin_idx] ? 
                                           gpio_pin_level[pin_idx] : 1'bz;
            assign gpio_pin_do[pin_idx] = gpio_pin_val[pin_idx];  
        end
    endgenerate

    generate begin
       case (`NRV_IO_GPIOS_WIDTH)
       8: 
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
             gpio_pin_level <= 0;
             gpio_dir_ctrl  <= 0;
        end 
        else begin
           if(gpio_wr && sel) begin
              gpio_dir_ctrl  <= {gpio_wdat[23:16]};
              gpio_pin_level <= {gpio_wdat[31:24]};
           end
        end
    end

       default: 
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
             gpio_pin_level <= 0;
             gpio_dir_ctrl  <= 0;
        end 
        else begin
           if(gpio_wr && sel) begin
              gpio_dir_ctrl  <= {gpio_wdat[23-pad_bits:16]};
              gpio_pin_level <= {gpio_wdat[31-pad_bits:24]};
           end
        end
    end

          endcase
       end   
    endgenerate
    
endmodule


