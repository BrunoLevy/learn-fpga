/*
Info: 	         ICESTORM_LC:   246/ 1280    19%
Info: 	        ICESTORM_RAM:     0/   16     0%
Info: 	               SB_IO:    11/  112     9%
Info: 	               SB_GB:     6/    8    75%
Info: 	        ICESTORM_PLL:     1/    1   100%
Info: 	         SB_WARMBOOT:     0/    1     0%
*/

/*****************************************************************/

module oled(
   input wire pclk,
   output wire D1,D2,D3,D4,D5,
   output wire oled_DIN, oled_CLK, oled_CS, oled_DC, oled_RST
);

   /*****************************************************************/

/*   
   wire clk;
   SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      
      // 65 MHz  -> SPI operates at 33 MHz
      // (note: see Libs/SSD1351.v, divider 4 bits...)
       .DIVR(4'b0000),
       .DIVF(7'b1010110),
       .DIVQ(3'b100),

      // 48 MHz  -> SPI operates at 24 MHz
      //.DIVR(4'b0000),
      //.DIVF(7'b0111111),
      //.DIVQ(3'b101),

      .FILTER_RANGE(3'b001),
   ) pll (
      .REFERENCECLK(pclk),
      .PLLOUTCORE(clk),
      .RESETB(1'b1),
      .BYPASS(1'b0)
   );
*/

   wire clk=pclk;
   
   /*****************************************************************/   
   
   reg[16:0] PC;

   wire [8:0] init_program;
   SSD1351InitROM ROM(
      .address(PC[5:0]),
      .data(init_program)
   );

   reg initialized = 1'b0;

   wire [15:0] pixel_color;


   reg[31:0] frame;

   wire [15:0] pixel_coords = (PC-1);        // -1 because PC==0 => write RAM command
   wire [6:0]  pixel_X = pixel_coords[7:1];  // divide by two because two bytes per pixel
   wire [6:0]  pixel_Y = pixel_coords[13:8]; // idem here.
   
   wire [4:0]  pixel_B = pixel_X + frame;
   wire [4:0]  pixel_R = pixel_Y + frame;
   wire [4:0]  pixel_G = (pixel_X >> 3);

   wire [8:0] display_program = 
      (PC ==  0) ? 9'h0_5c : // Write RAM
      (PC ==  128*128*2+1) ? 9'h0_00 :
      PC[0] ? {1'b1, pixel_color[15:8] } : {1'b1, pixel_color[7:0] } ;
   
   wire [8:0] program = initialized ? display_program : init_program;
   assign pixel_color = {pixel_R, pixel_G, 1'b0, pixel_B}; // pixel format: RGB 565


   wire oled_busy;
   reg wr = 1'b1;
   
   SSD1351 SSD(
      .clk(clk),
      .wr(wr),
      .data(program),
      .busy(oled_busy),
      .DIN(oled_DIN),
      .CLK(oled_CLK),
      .CS(oled_CS),
      .DC(oled_DC),
      .RST(oled_RST),
  );

  assign {D5,D4,D3,D2,D1} = (PC+1);

  always @(posedge clk) begin
     if(program == 9'h0_00) begin
        initialized <= 1'b1;
	frame <= frame + 1;
  	PC <= 0;
 	wr <= 1;
     end else begin
        if(oled_busy) begin
           wr <= 1'b0;
	end else if(!wr) begin
           PC <= PC + 1;
  	   wr <= 1'b1; 
	end
     end
  end


endmodule
