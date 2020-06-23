#include <femtorv32.h>

/*
 * Reading the ST-NICCC megademo data stored in
 * the SPI flash and streaming it to polygons.
 * Note: the polygon stream needs to be implanted
 * in SPI flash, using:
 * iceprog -o 1M C_EXAMPLES/DATA/scene1.bin
 */

uint32_t spi_addr = 1024*1024;

#define BUSY 256
uint8_t next_spi_byte() {
   int result = BUSY;
   while(result & BUSY) {
       result = IO_IN(IO_SPI_FLASH);
   }
   IO_OUT(IO_SPI_FLASH, spi_addr);
   result = BUSY;
   while(result & BUSY) {
       result = IO_IN(IO_SPI_FLASH);
   }
   ++spi_addr;
   return (uint8_t)(result & 255);
}

uint16_t next_spi_word() {
   /* words are stored in big endian format */
   uint16_t hi = (uint16_t)next_spi_byte();    
   uint16_t lo = (uint16_t)next_spi_byte();
   return (hi << 8) | lo;
}


uint16_t cmap[16];
uint8_t  X[255];
uint8_t  Y[255];
int      poly[30];

#define CLEAR_BIT   1
#define PALETTE_BIT 2
#define INDEXED_BIT 4

/* returns 0 at last frame */
int read_frame() {
    uint8_t frame_flags = next_spi_byte();
    if(frame_flags & PALETTE_BIT) {
	uint16_t colors = next_spi_word();
	for(int b=15; b>=0; --b) {
	    if(colors & (1 << b)) {
		int rgb = next_spi_word();
		int b3 = (rgb & 0x007);
		int g3 = (rgb & 0x070) >> 4;
		int r3 = (rgb & 0x700) >> 8;
		cmap[15-b] = GL_RGB((r3 << 5), (g3 << 5), (b3 << 5));
	    }
	}
    }

    if(frame_flags & CLEAR_BIT) {
	GL_clear();
    }

    if(frame_flags & INDEXED_BIT) {
	uint8_t nb_vertices = next_spi_byte();
	for(int v=0; v<nb_vertices; ++v) {
	    X[v] = next_spi_byte() >> 1;
	    Y[v] = next_spi_byte() >> 1;
	}
    }

    for(;;) {
	uint8_t poly_desc = next_spi_byte();
	if(poly_desc == 0xff) {
	    break; // end of frame
	}
	if(poly_desc == 0xfe) {
	    // Go to next 64kb block
	    spi_addr &= ~65535;
	    spi_addr +=  65536;
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
		poly[2*i]   = next_spi_byte() >> 1;
		poly[2*i+1] = next_spi_byte() >> 1;		
	    }
	}

	GL_polygon_mode(GL_POLY_FILL);	
	GL_fill_poly(nvrtx,poly,cmap[poly_col]);
//	GL_polygon_mode(GL_POLY_LINES);
//	GL_fill_poly(nvrtx,poly,0);	
    }
    return 1; 
}


int main() {
    spi_addr = 1024*1024;    
    GL_init();
    GL_clear();
    while(read_frame()) {
	delay(50);
    }
}
