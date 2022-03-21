module bench();
   reg clock;
   wire [4:0] leds;
   wire leds_active;

   SOC uut(
     .clock(clock),
     .leds(leds),
     .leds_active(leds_active)
   );
   
   initial begin
      clock = 0;
      forever begin
	 #1 clock = ~clock;
	 if(leds_active && clock) begin
	    $display("LEDS = %b",leds);
	 end   
      end
   end
endmodule   
   
