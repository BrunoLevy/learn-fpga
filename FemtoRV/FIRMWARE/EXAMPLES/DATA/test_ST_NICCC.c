/*
 * Standalone test program that reads scene1.bin
 * and that displays what it finds in there,
 * see scene_description.txt
 * (it is easier to debug this one than on-device).
 * The on-device version is in C_EXAMPLES/ST_NICCC.c.
 */

#include <stdio.h>
#include <stdlib.h>

typedef unsigned char  uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int   uint32_t;

#define GL_RGB(R,G,B) ((((((R) & 0xF8) << 2) | ((G) & 0xF8)) << 6) | ((B) >> 3))

FILE* stream = NULL;

/*
 * Reading the ST-NICCC megademo data.
 * (compared with the version in C_EXAMPLES, this version
 *  reads a file instead of reading from the SPI Flash memory).
 */

int cur_spi = 0;

uint8_t next_spi_byte() {
   uint8_t result;
   fread(&result, 1, 1, stream);
   ++cur_spi;
   return result;
}


uint16_t next_spi_word() {
   /* words are stored in big endian format */
   uint16_t hi  = (uint16_t)next_spi_byte();    
   uint16_t low = (uint16_t)next_spi_byte();
   return low | (hi << 8);
}

void printb(int x) {
   for(int s=15; s>=0; --s) {
      putchar(x & (1 << s) ? '1' : '0');
   }
}


uint16_t cmap[16];
int  X[255];
int  Y[255];
int      poly[30];

#define CLEAR_BIT   1
#define PALETTE_BIT 2
#define INDEXED_BIT 4


/* returns 0 at last frame */
int read_frame() {
   static int frame = 0;
   
   printf("================Frame %d\n", frame);
   ++frame;
   
    uint8_t frame_flags = next_spi_byte();
   
    printf(
	   "Frame flags: %d:%c%c%c\n",
	   frame_flags,
	   (frame_flags & CLEAR_BIT) ? 'C' : '_',
	   (frame_flags & PALETTE_BIT) ? 'P' : '_',
	   (frame_flags & INDEXED_BIT) ? 'I' : '_'
    );
   
    if(frame_flags & CLEAR_BIT) {
	/*
	 * clear the screen now:
	 * GL_clear();
	 */
    }
    
    if(frame_flags & PALETTE_BIT) {
	uint16_t colors = next_spi_word();
        printf("mask=");
        printb(colors);
        printf("\n");
	for(int b=0; b<16; ++b) {
	    if(colors & (1 << b)) {
	       uint16_t rgb = next_spi_word();
	       cmap[15-b] = rgb;
	       printf("CMAP %d:",15-b);
	       printf(" ");
	       printb(rgb);
	       printf("     ");

	       int b3 = (rgb & 0x007);
	       int g3 = (rgb & 0x070) >> 4;
	       int r3 = (rgb & 0x700) >> 8;
	       printf(" ->RGB: %d %d %d\n", r3<<5,g3<<5,b3<<5);
	    }
	}
    }

    if(frame_flags & CLEAR_BIT) {
    }

    for(int i=0; i<255; ++i) {
	X[i] = 65536;
	Y[i] = 65536;
    }
     
    
    if(frame_flags & INDEXED_BIT) {
	uint8_t nb_vertices = next_spi_byte();
        printf("nb vrtx:%d\n", nb_vertices);
	for(int v=0; v<nb_vertices; ++v) {
	   X[v] = next_spi_byte() >> 1;
	   Y[v] = next_spi_byte() >> 1;
	   printf("  vrtx %d: %d %d\n", v, X[v], Y[v]);
	}
    }

    for(;;) {
	uint8_t poly_desc = next_spi_byte();
	if(poly_desc == 0xff) {
	    break; // end of frame
	}
	if(poly_desc == 0xfe) {
	   printf("=====>Skipping to 64k boundary\n");
	   while(cur_spi & 65535) {
	      next_spi_byte();
	   }
	   return 1;
	}
	if(poly_desc == 0xfd) {
	   printf("End of stream \n");
	   return 0; 
	}
	uint8_t nvrtx = poly_desc & 15;
	uint8_t poly_col = poly_desc >> 4;
        printf("POLY col:%d nv:%d ", poly_col, nvrtx);
	for(int i=0; i<nvrtx; ++i) {
	    if(frame_flags & INDEXED_BIT) {
		uint8_t index = next_spi_byte();
		poly[2*i]   = X[index];
		poly[2*i+1] = Y[index];
	        printf("%d:%d,%d ",index,X[index],Y[index]);
	    } else {
		poly[2*i]   = next_spi_byte() >> 1;
		poly[2*i+1] = next_spi_byte() >> 1;	
	        printf("%d,%d ", poly[2*i], poly[2*i+1]);
	    }
	}
        printf("\n");

        for(int i=0; i<2*nvrtx; ++i) {
	   if(poly[i] < 0 ||poly[i] > 127) {
	      printf("ERROR =====>\n");
	   }
	}
       
        /*
	 * Draw the polygon now:
	 * GL_fill_poly(nvrtx,poly,cmap[poly_col]);
	 */ 
    }
    return 1; 
}


int main() {
    stream = fopen("scene1.dat","rb");
    while(read_frame()) {
    }
}
