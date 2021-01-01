// Simple tri-colour LED blink example.

// Correctly map pins for the iCE40UP5K SB_RGBA_DRV hard macro.
// The variables EVT, PVT and HACKER are set from the Makefile.
`ifdef EVT
`define BLUEPWM  RGB0PWM
`define REDPWM   RGB1PWM
`define GREENPWM RGB2PWM
`elsif HACKER
`define BLUEPWM  RGB0PWM
`define GREENPWM RGB1PWM
`define REDPWM   RGB2PWM
`elsif PVT
`define GREENPWM RGB0PWM
`define REDPWM   RGB1PWM
`define BLUEPWM  RGB2PWM
`else
`error_board_not_supported
`endif

module top (
    // 48MHz Clock input
    // --------
    input clki,
    // LED outputs
    // --------
    output rgb0,
    output rgb1,
    output rgb2,
    // USB Pins (which should be statically driven if not being used).
    // --------
    output usb_dp,
    output usb_dn,
    output usb_dp_pu
);

    // Assign USB pins to "0" so as to disconnect Fomu from
    // the host system.  Otherwise it would try to talk to
    // us over USB, which wouldn't work since we have no stack.
    assign usb_dp = 1'b0;
    assign usb_dn = 1'b0;
    assign usb_dp_pu = 1'b0;

    // Connect to system clock (with buffering)
    wire clk;
    SB_GB clk_gb (
        .USER_SIGNAL_TO_GLOBAL_BUFFER(clki),
        .GLOBAL_BUFFER_OUTPUT(clk)
    );

    // Use counter logic to divide system clock.  The clock is 48 MHz,
    // so we divide it down by 2^28.
    reg [28:0] counter = 0;
    always @(posedge clk) begin
        counter <= counter + 1;
    end

    // Instantiate iCE40 LED driver hard logic, connecting up
    // counter state and LEDs.
    //
    // Note that it's possible to drive the LEDs directly,
    // however that is not current-limited and results in
    // overvolting the red LED.
    //
    // See also:
    // https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/IK/ICE40LEDDriverUsageGuide.ashx?document_id=50668
    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),       // half current
        .RGB0_CURRENT("0b000011"),  // 4 mA
        .RGB1_CURRENT("0b000011"),  // 4 mA
        .RGB2_CURRENT("0b000011")   // 4 mA
    ) RGBA_DRIVER (
        .CURREN(1'b1),
        .RGBLEDEN(1'b1),
        .`BLUEPWM(counter[25]),     // Blue
        .`REDPWM(counter[24]),      // Red
        .`GREENPWM(counter[23]),    // Green
        .RGB0(rgb0),
        .RGB1(rgb1),
        .RGB2(rgb2)
    );

endmodule
