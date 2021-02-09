/*
 * Reading the ST-NICCC megademo data stored in
 * the SDCard and streaming it to polygons,
 * rendered on the OLED display using femtoGL.
 * 
 * femtosoc options (femtosoc.v):
 *   OLED display (NRV_IO_SSD1351)
 *   FGA          (NRV_IO_FGA)
 *   SDCard       (NRV_IO_SPI_SDCARD)
 * 
 * The polygon stream is a 640K file (DATA/scene1.dat),
 * that needs to be stored on the SD card. 
 *
 * More details and links in C_EXAMPLES/DATA/notes.txt
 */

#include <femtoGL.h>

FILE* F = 0;
int cur_byte_address = 0;

uint8_t next_byte() {
    uint8_t result;
    fread(&result, 1, 1, F);
    ++cur_byte_address;
    return result;
}

uint16_t next_word() {
   /* In the ST-NICCC file,  
    * words are stored in big endian format.
    * (see DATA/scene_description.txt).
    */
   uint16_t hi = (uint16_t)next_byte();    
   uint16_t lo = (uint16_t)next_byte();
   return (hi << 8) | lo;
}


int colormapped; // 1 if colormapped, 0 if RGB16

static inline void map_vertex(int16_t* X, int16_t* Y) {
   if(FGA_mode == FGA_MODE_640x400x4bpp) {
      *X = *X << 1;
      *Y = *Y << 1;
   } else if(FGA_mode == GL_MODE_OLED) {
      *X = *X >> 1;
      *Y = *Y >> 1;
#ifdef SSD1331
      *X -= (128 - OLED_WIDTH)/2;
      *Y -= (128 - OLED_HEIGHT)/2;      
#endif
   }
}


/* 
 * The colormap, encoded in such a way that it
 * can be directly sent to the OLED display.
 */
uint16_t cmap[16];

/*
 * Current frame's vertices coordinates (if frame is indexed).
 */
int16_t  X[255];
int16_t  Y[255];

/*
 * Current polygon vertices, as expected
 * by GL_fill_poly():
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
 * SPI flash and rasterizes the polygons using
 * FemtoGL.
 * returns 0 if last frame.
 *   See DATA/scene_description.txt for the 
 * ST-NICCC file format.
 *   See DATA/test_ST_NICCC.c for an example
 * program.
 */
int read_frame() {
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
		
		// Re-encode them as FemtoGL color for the OLED display:
		// RRRRR GGGGG 0 BBBBB
		cmap[15-b] = (b3 << 2) | (g3 << 8) | (r3 << 13);
	       
	        // Send to femtoGL
	        FGA_setpalette(15-b, r3 << 5, g3 << 5, b3 << 5); 
	    }
	}
    }

    GL_wait_vbl();
    if(wireframe) {
       GL_clear();
    } else {
        if(frame_flags & CLEAR_BIT) {
	   // GL_clear(); // Too much flickering, commented-out for now
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
        GL_fill_poly(nvrtx,poly,colormapped ? poly_col : cmap[poly_col]);
        /*       
        if(FGA_mode == GL_MODE_OLED) {
	   GL_fill_poly(nvrtx,poly,cmap[poly_col]);
	} else {
	   FGA_fill_poly(nvrtx,poly,colormapped ? poly_col : cmap[poly_col]);
	}
	*/ 
    }
    return 1; 
}


int main() {
    GL_init(GL_MODE_CHOOSE);
    GL_clear();
    colormapped = (FGA_mode == FGA_MODE_320x200x8bpp ||
                   FGA_mode == FGA_MODE_640x400x4bpp  );
   
    if(filesystem_init()) {
       return -1;
    }
   
    wireframe = 0;
   
    for(;;) {
        cur_byte_address = 0;
	F = fopen("/scene1.dat","r");
	if(!F) {
	    printf("Could not open scene1.dat\n");
	    return -1;
	}
        GL_clear();
	GL_polygon_mode(wireframe ? GL_POLY_LINES: GL_POLY_FILL);	
	while(read_frame()) {
	   // delay(50); // If GL_clear() is uncommented, uncomment as well
	   //            // to reduce flickering.
	}
        wireframe = !wireframe;
	fclose(F);
    }
}
