/*
 * Generates rescaling tables for the OLED driver
 */

#include <stdint.h>
#include <stdio.h>

#define OLED_WIDTH   96
#define OLED_HEIGHT  64

static inline int map(int x, int in_max, int out_max) {
    return x * in_max / out_max;
}

static inline int map_delta(int x, int in_max, int out_max) {
    if(x == 0) {
        return 0;
    }
    return map(x, in_max, out_max) - map(x-1, in_max, out_max);
}


// Stocker les deltas
// Pour Y, shifter pour que ca tienne dans un octet

int main() {
   
    printf("uint8_t oled_map_x[OLED_WIDTH]={\n");
    for(int x=0; x<OLED_WIDTH; ++x) {
        printf("%d",map_delta(x, 320, OLED_WIDTH));
        if(x < OLED_WIDTH-1) {
            printf(",");
        }
    }
    printf("};\n\n");
    
    printf("uint8_t oled_map_y[OLED_HEIGHT]={\n");
    for(int y=0; y<OLED_HEIGHT; ++y) {
        printf("%d",(map_delta(y, 200, OLED_HEIGHT)*320)>>3);
        if(y < OLED_HEIGHT-1) {
            printf(",");
        }
    }
    printf("};\n");
}
