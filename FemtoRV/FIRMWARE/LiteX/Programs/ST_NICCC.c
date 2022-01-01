/*
 * Reading the ST-NICCC megademo data stored in
 * the SDCard and streaming it to polygons,
 * rendered in the framebuffer.
 * 
 * The polygon stream is a 640K file 
 * (C_EXAMPLES/DATA/scene1.dat), that needs to 
 * be stored on the SD card. 
 *
 * More details and links in C_EXAMPLES/DATA/notes.txt
 */

#include "lite_fb.h"
#include <libfatfs/ff.h>
#include <libbase/uart.h>
#include <libbase/console.h>
#include <stdio.h>
#include <string.h>

FATFS fs;
FIL F;
int cur_byte_address = 0;


// Default fullres if blitter is there, else default is 
// small res.
#ifdef CSR_BLITTER_BASE
int fullres = 1;
#else
int fullres = 0;
#endif

static uint8_t next_byte(void) {
    uint8_t result;
    UINT br;
    f_read(&F, &result, 1, &br);
    ++cur_byte_address;
    return result;
}

static uint16_t next_word(void) {
   /* In the ST-NICCC file,  
    * words are stored in big endian format.
    * (see DATA/scene_description.txt).
    */
   uint16_t hi = (uint16_t)next_byte();    
   uint16_t lo = (uint16_t)next_byte();
   return (hi << 8) | lo;
}


static inline void map_vertex(int16_t* X, int16_t* Y) {
   if(fullres) {
      *X = *X << 1; // for a larger picture (but too slow)
      *Y = *Y << 1;
   } else {
      *X += 160;
      *Y += 100;
   }
}


static void clear(void) {
   if(fullres) {
      fb_clear();
   } else {
      fb_fillrect(160,100,480,300,0);
   }
}



/* 
 * The colormap, encoded in such a way that it
 * can be directly sent to the OLED display.
 */
uint32_t cmap[16];

/*
 * Current frame's vertices coordinates (if frame is indexed).
 */
int16_t  X[255];
int16_t  Y[255];

/*
 * Current polygon vertices, as expected
 * by fb_fill_poly():
 * xi = poly[2*i], yi = poly[2*i+1]
 */
int      poly[30];

int wireframe = 0;

/*
 * Masks for frame flags.
 */
#define CLEAR_BIT   1
#define PALETTE_BIT 2
#define INDEXED_BIT 4

/*
 * Reads a frame's polygonal description from
 * file and rasterizes the polygons using
 * FemtoGL.
 * returns 0 if last frame.
 *   See DATA/scene_description.txt for the 
 * ST-NICCC file format.
 *   See DATA/test_ST_NICCC.c for an example
 * program.
 */
static int read_frame(void) {
    uint8_t frame_flags = next_byte();

    // Update palette data.
    if(frame_flags & PALETTE_BIT) {
	uint16_t colors = next_word();
	for(int b=15; b>=0; --b) {
	    if(colors & (1 << b)) {
		int rgb = next_word();
	       
		// Get the three 3-bits per component R,G,B
	        int b3 = (rgb & 0x007);
		int g3 = (rgb & 0x070) >> 4;
		int r3 = (rgb & 0x700) >> 8;
		
		// Re-encode them as 24bpp color
		cmap[15-b] = fb_RGB(r3 << 5, g3 << 5, b3 << 5);
	    }
	}
    }

    // GL_wait_vbl();
    if(wireframe) {
       clear();
    } else {
        if(frame_flags & CLEAR_BIT) {
	   clear(); 
	}
    }
   
    // Update vertices
    if(frame_flags & INDEXED_BIT) {
	uint8_t nb_vertices = next_byte();
	for(int v=0; v<nb_vertices; ++v) {
	   X[v] = next_byte();
	   Y[v] = next_byte();
	   map_vertex(&X[v],&Y[v]);
	}
    }

    // Draw frame's polygons
    for(;;) {
	uint8_t poly_desc = next_byte();

	// Special polygon codes (end of frame,
	// seek next block, end of stream)
	
	if(poly_desc == 0xff) {
	    break; // end of frame
	}
	if(poly_desc == 0xfe) {
	   // Go to next 64kb block
	   // (TODO: with fseek !)
	   while(cur_byte_address & 65535) {
	      next_byte();
	   }
	   return 1; 
	}
	if(poly_desc == 0xfd) {
	    return 0; // end of stream
	}
	
	uint8_t nvrtx = poly_desc & 15;
	uint8_t poly_col = poly_desc >> 4;
	for(int i=0; i<nvrtx; ++i) {
	    if(frame_flags & INDEXED_BIT) {
		uint8_t index = next_byte();
		poly[2*i]   = X[index];
		poly[2*i+1] = Y[index];
	    } else {
	       int16_t x,y;
	       x = next_byte();
	       y = next_byte();
	       map_vertex(&x,&y);
	       poly[2*i]   = x;
	       poly[2*i+1] = y;
	    }
	}
        fb_fill_poly(nvrtx,poly,cmap[poly_col]);
    }
    return 1; 
}


int main(int argc, char** argv) {
   
   int run = 1;
   fb_init();
   fb_set_dual_buffering(1);
   wireframe = 0;

   
   if(argc == 2 && !strcmp(argv[1],"-small")) {
      fullres = 0;
   }

   if(argc == 2 && !strcmp(argv[1],"-large")) {
      fullres = 1;
   }
   
   if(f_mount(&fs,"",1) != FR_OK) {
      printf("Could not mount filesystem\n");
      return -1;
   }    
   
    while(run) {
        cur_byte_address = 0;
        if(f_open(&F, "scene1.dat",FA_READ) != FR_OK) {
	    printf("Could not open scene1.dat\n");
	    return -1;
	}
        fb_set_poly_mode(wireframe ? FB_POLY_LINES: FB_POLY_FILL);
	while(read_frame()) {
	   fb_swap_buffers();
	   if (readchar_nonblock()) {
	      getchar();
	      run = 0;
	      break;
	   }
	}
        wireframe = !wireframe;
	f_close(&F);
    }
}
