/*
 * Grabbed and adapted from the demos from the ImGUI demos contest:
 * https://github.com/ocornut/imgui/issues/3606
 */ 
#include "imgui_emul.h"
#include <stdlib.h>

#define W OLED_WIDTH
#define H OLED_HEIGHT

// Convert a 24 bit ImGui color into a 16 bit color for the OLED display
#define C16(RGB) GL_RGB(RGB & 255,(RGB >> 8) & 255,(RGB >> 16) & 255)

unsigned int n = 0;
unsigned int C[666]={
   C16(0xFFFFFF),C16(0xC7EFEF),C16(0x9FDFDF),C16(0x6FCFCF),C16(0x37B7B7),
   C16(0x2FB7B7),C16(0x2FAFB7),C16(0x2FAFBF),C16(0x27A7BF),C16(0x27A7BF),
   C16(0x1F9FBF),C16(0x1F9FBF),C16(0x1F97C7),C16(0x178FC7),C16(0x1787C7),
   C16(0x1787CF),C16(0xF7FCF),C16(0xF77CF),C16(0xF6FCF),C16(0xF67D7),
   C16(0x75FD7),C16(0x75FD7),C16(0x757DF),C16(0x757DF),C16(0x74FDF),
   C16(0x747C7),C16(0x747BF),C16(0x73FAF),C16(0x72F9F),C16(0x7278F),
   C16(0x71F77),C16(0x71F67),C16(0x71757),C16(0x70F47),C16(0x70F2F),
   C16(0x7071F),C16(0x70707)
};

unsigned char T[H+2][W];

void FX(ImVec2 a, ImVec2 b, ImVec2 s,float t) {
   if(20*t>n) {
      n++;
   } else {
      t = 0;
   }
   oled_write_window(0,0,W-1,H-1);
   for(unsigned int x=0;x<H;x++)
     for(unsigned int y=0;y<W;y++) {
	unsigned int RGB = C[T[y+1][x]];
	OLED_WRITE_DATA_UINT16(RGB);
	unsigned int r=3&rand();
	if(t)
	  T[y+1][x]=T[y][x+r-(r>1)]+(r&1);
     }
}
