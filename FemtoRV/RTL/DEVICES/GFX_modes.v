
// Define one of:
// MODE_640x480, MODE_800x600, MODE_1024x768, MODE_1280x1024.

/********************** Modes ****************************/

`ifdef MODE_640x480
   localparam GFX_pixel_clock   = 25;
   localparam GFX_width         = 640;
   localparam GFX_height        = 480;
   localparam GFX_h_front_porch = 16;
   localparam GFX_h_sync_width  = 96;
   localparam GFX_h_back_porch  = 48;
   localparam GFX_v_front_porch = 10;
   localparam GFX_v_sync_width  = 2;
   localparam GFX_v_back_porch  = 32;
`endif

`ifdef MODE_800x600
   localparam GFX_pixel_clock   = 40;
   localparam GFX_width         = 800;
   localparam GFX_height        = 600;
   localparam GFX_h_front_porch = 40;
   localparam GFX_h_sync_width  = 128;
   localparam GFX_h_back_porch  = 88;
   localparam GFX_v_front_porch = 1;
   localparam GFX_v_sync_width  = 4;
   localparam GFX_v_back_porch  = 23;
`endif

`ifdef MODE_1024x768
   localparam GFX_pixel_clock   = 65;
   localparam GFX_width         = 1024;
   localparam GFX_height        = 768;
   localparam GFX_h_front_porch = 24;
   localparam GFX_h_sync_width  = 136;
   localparam GFX_h_back_porch  = 160;
   localparam GFX_v_front_porch = 3;
   localparam GFX_v_sync_width  = 6;
   localparam GFX_v_back_porch  = 29;

`endif

`ifdef MODE_1280x1024
   localparam GFX_pixel_clock   = 108;
   localparam GFX_width         = 1280;
   localparam GFX_height        = 1024;
   localparam GFX_h_front_porch = 48;
   localparam GFX_h_sync_width  = 112;
   localparam GFX_h_back_porch  = 248;
   localparam GFX_v_front_porch = 1;
   localparam GFX_v_sync_width  = 3;
   localparam GFX_v_back_porch  = 38;
`endif

localparam GFX_line_width = GFX_width  + GFX_h_front_porch + GFX_h_sync_width + GFX_h_back_porch;
localparam GFX_lines      = GFX_height + GFX_v_front_porch + GFX_v_sync_width + GFX_v_back_porch;
