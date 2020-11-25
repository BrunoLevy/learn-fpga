/* 
 * Helper for porting demos from the ImGUI demos contest:
 * https://github.com/ocornut/imgui/issues/3606
 */ 

#ifndef H_IMGUI_EMUL_H
#define H_IMGUI_EMUL_H

#include <femtorv32.h>
#include <math.h>


int __errno; // Missing when linking (I don't know why ...)

typedef int bool;

#define true 1
#define false 0

typedef struct  {
   float x;
   float y;
} ImVec2;

static inline ImVec2 vec2(float x, float y) {
   ImVec2 V;
   V.x = x;
   V.y = y;
   return V;
}

static inline ImVec2 vec2_add(ImVec2 U, ImVec2 V) {
   return vec2(U.x+V.x, U.y+V.y);
}

static inline ImVec2 vec2_mul(ImVec2 U, ImVec2 V) {
   return vec2(U.x*V.x, U.y*V.y);
}

static inline ImVec2 vec2_scale(ImVec2 U, float s) {
   return vec2(U.x*s, U.y*s);
}

static inline uint16_t GL_RGB_f(float r, float g, float b) {
  int R = (int)(r*255.0);
  int G = (int)(g*255.0);
  int B = (int)(b*255.0);
  R = (R<0)   ? 0   : R;
  R = (R>255) ? 255 : R;
  G = (G<0)   ? 0   : G;
  G = (G>255) ? 255 : G;
  B = (B<0)   ? 0   : B;
  B = (B>255) ? 255 : B;
  return GL_RGB(R,G,B);
}

#define IM_PI 3.1415926535

// ImGui contest resolution: 320x180
// OLED screen resolution:   128x128
void addQuad(ImVec2 A, ImVec2 B, ImVec2 C, ImVec2 D, uint32_t color) {
   uint16_t r = (uint16_t)(color & 255);
   color = color >> 8;
   uint16_t g = (uint16_t)(color & 255);
   color = color >> 8;
   uint16_t b = (uint16_t)(color & 255);   
   int pts[8];
   const int offx = 128/2 - 320/4;
   const int offy = 128/2 - 180/4;
   pts[0] = (int)A.x / 2 + offx;
   pts[1] = (int)A.y / 2 + offy;
   pts[2] = (int)B.x / 2 + offx;
   pts[3] = (int)B.y / 2 + offy;
   pts[4] = (int)C.x / 2 + offx;
   pts[5] = (int)C.y / 2 + offy;
   pts[6] = (int)D.x / 2 + offx;
   pts[7] = (int)D.y / 2 + offy;
   GL_fill_poly(4, pts, GL_RGB(r,g,b));
}


void addRectFilled(ImVec2 A, ImVec2 B, uint32_t color) {
   uint16_t r = (uint16_t)(color & 255);
   color = color >> 8;
   uint16_t g = (uint16_t)(color & 255);
   color = color >> 8;
   uint16_t b = (uint16_t)(color & 255);
   const int offx = 128/2 - 320/4;
   const int offy = 128/2 - 180/4;
   int x1 = (int)A.x / 2 + offx;
   int y1 = (int)A.y / 2 + offy;
   int x2 = (int)B.x / 2 + offx;
   int y2 = (int)B.y / 2 + offy;
   x1 = (x1 < 0) ? 0 : x1;
   x1 = (x1 > 127) ? 127 : x1;
   y1 = (y1 < 0) ? 0 : y1;
   y1 = (y1 > 127) ? 127 : y1;
   x2 = (x2 < 0) ? 0 : x2;
   x2 = (x2 > 127) ? 127 : x2;
   y2 = (y2 < 0) ? 0 : y2;
   y2 = (y2 > 127) ? 127 : y2;   
   GL_fill_rect(x1,y1,x2,y2,GL_RGB(r,g,b));
}

void FX(ImVec2 a, ImVec2 b, ImVec2 d, float t); 

void main() {
   ImVec2 a = vec2(0,0);
   ImVec2 b = vec2(320,180);
   ImVec2 d = vec2(320,180);
   float  t = 0.0;
   GL_init();
   GL_clear();

   for(;;) {
      FX(a,b,d,t);
      t = t+0.1;
   }
}

/**************************************************/

#endif

