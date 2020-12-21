/*
 * Reading the ST-NICCC megademo data stored in
 * the SDCard and streaming it to polygons,
 * rendered on the OLED display using femtoGL.
 * 
 * femtosoc options (femtosoc.v):
 *   OLED display (NRV_IO_SSD1351)
 *   SDCard       (NRV_IO_SPI_SDCARD)
 * 
 * The polygon stream is a 640K file (DATA/scene1.bin), 
 * that needs to be stored on the SD card and renamed
 * as scene1.dat (because .bin is the extension for our
 * programs)
 *
 * More details and links in C_EXAMPLES/DATA/notes.txt
 */

#include <femtorv32.h>

FILE* F = 0;
int cur_spi = 0;

uint8_t next_spi_byte() {
    uint8_t result;
    fread(&result, 1, 1, F);
    ++cur_spi;
    return result;
}

uint16_t next_spi_word() {
   /* In the ST-NICCC file,  
    * words are stored in big endian format.
    * (see DATA/scene_description.txt).
    */
   uint16_t hi = (uint16_t)next_spi_byte();    
   uint16_t lo = (uint16_t)next_spi_byte();
   return (hi << 8) | lo;
}

/* 
 * The colormap, encoded in such a way that it
 * can be directly sent to the OLED display.
 */
uint16_t cmap[16];

/*
 * Current frame's vertices coordinates (if frame is indexed),
 *  mapped to OLED display dimensions (divide by 2 from file).
 */
uint8_t  X[255];
uint8_t  Y[255];

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
    uint8_t frame_flags = next_spi_byte();

    // Update palette data.
    if(frame_flags & PALETTE_BIT) {
	uint16_t colors = next_spi_word();
	for(int b=15; b>=0; --b) {
	    if(colors & (1 << b)) {
		int rgb = next_spi_word();
	       
		// Get the three 3-bits per component R,G,B
	        int b3 = (rgb & 0x007);
		int g3 = (rgb & 0x070) >> 4;
		int r3 = (rgb & 0x700) >> 8;
		
		// Re-encode them as FemtoGL color for the OLED display:
		// RRRRR GGGGG 0 BBBBB
		cmap[15-b] = (b3 << 2) | (g3 << 8) | (r3 << 13);
	    }
	}
    }

    if(wireframe) {
	GL_clear();
    } else {
	if(frame_flags & CLEAR_BIT) {
	    // GL_clear(); // Commented out, too much flickering,
	                   // cannot VSynch on the OLED display.
	}
    }

    // Update vertices
    if(frame_flags & INDEXED_BIT) {
	uint8_t nb_vertices = next_spi_byte();
	for(int v=0; v<nb_vertices; ++v) {
	    X[v] = (next_spi_byte() >> 1);
	    Y[v] = (next_spi_byte() >> 1) + 14;
	}
    }

    // Draw frame's polygons
    for(;;) {
	uint8_t poly_desc = next_spi_byte();

	// Special polygon codes (end of frame,
	// seek next block, end of stream)
	
	if(poly_desc == 0xff) {
	    break; // end of frame
	}
	if(poly_desc == 0xfe) {
	   // Go to next 64kb block
	   // (TODO: with fseek !)
	   while(cur_spi & 65535) {
	      next_spi_byte();
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
		uint8_t index = next_spi_byte();
		poly[2*i]   = X[index];
		poly[2*i+1] = Y[index];
	    } else {
		poly[2*i]   = (next_spi_byte() >> 1);
		poly[2*i+1] = (next_spi_byte() >> 1) + 14;		
	    }
	}
	GL_fill_poly(nvrtx,poly,cmap[poly_col]);
    }
    return 1; 
}


int main() {
    GL_tty_init();
    GL_clear();
    printf("ST-NICCC demo\n");
    if(sd_init()) {
        printf("Could not initialize SDCard\n");
	return -1;
    }
    fl_init();
    if(fl_attach_media((fn_diskio_read)sd_readsector, (fn_diskio_write)sd_writesector) != FAT_INIT_OK) {
        printf("ERROR: Failed to init file system\n");
	return -1;
    }
    GL_clear();
    wireframe = 0;

    for(;;) {
        cur_spi = 0;
	F = fopen("/scene1.dat","r");
	if(!F) {
	    printf("Could not open scene1.dat\n");
	    return -1;
	}
	GL_polygon_mode(wireframe ? GL_POLY_LINES: GL_POLY_FILL);	
	while(read_frame()) {
	    // delay(50); // If GL_clear() is uncommented, uncomment as well
	                  // to reduce flickering.
	}
	wireframe = !wireframe;
	fclose(F);
    }
}
