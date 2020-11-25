// Ported from the ImGUI demos contest:
// https://github.com/ocornut/imgui/issues/3606

// Note: it is super slow on FemtoRV32, the bottleneck
// comes from floating point operations. Polygon rasterization
// is reasonably fast (see ST_NICCC).

#include <femtorv32.h>
#include <math.h>

typedef int bool;

int __errno;

typedef struct  {
   float x;
   float y;
} ImVec2;

static inline ImVec2 make_vec2(float x, float y) {
   ImVec2 V;
   V.x = x;
   V.y = y;
   return V;
}

void Q(ImVec2 A, ImVec2 B, ImVec2 C, ImVec2 D, uint32_t color) {
   uint16_t r = (uint16_t)(color & 255);
   color = color >> 8;
   uint16_t g = (uint16_t)(color & 255);
   color = color >> 8;
   uint16_t b = (uint16_t)(color & 255);   
   int pts[8];
   pts[0] = (int)A.x / 2;
   pts[1] = (int)A.y / 2;
   pts[2] = (int)B.x / 2;
   pts[3] = (int)B.y / 2;
   pts[4] = (int)C.x / 2;
   pts[5] = (int)C.y / 2;
   pts[6] = (int)D.x / 2;
   pts[7] = (int)D.y / 2;
   GL_fill_poly(4, pts, GL_RGB(r,g,b));
}

void FX(ImVec2 a, ImVec2 b, ImVec2 d, float t) {
   static float cz = 0;
   ImVec2 bl = make_vec2(160, 90), br = bl, bri = bl, bli = bl;
   cz += 0.5f;
   // Q(a, make_vec2(b.x, a.y), make_vec2(b.x, a.y + 30), make_vec2(a.x, a.y + 30), 0xffffff00);
   // Q(make_vec2(a.x, a.y + 30), make_vec2(b.x, a.y + 30), b, make_vec2(a.x, b.y), 0xff007f00);
   
   for (int s = 300; s > 0; s--) {
      float c = sinf((cz + s) * 0.1f) * 500;
      float f = cosf((cz + s) * 0.02f) * 1000;
      ImVec2 tl = bl, tr = br, tli = bli, tri = bri;
      tli.y--;
      tri.y--;
      float ss = 0.003f / s;
      float w = 2000 * ss * 160;
      float px = a.x + 160 + (f * ss * 160);
      float py = 90 - (ss * (c * 2 - 2500) * 90);
      bl = make_vec2(px - w, py);
      br = make_vec2(px + w, py);
      w = 1750 * ss * 160;
      bli = make_vec2(px - w, py);
      bri = make_vec2(px + w, py);
      if (s != 300) {
	 bool j = fmodf(cz + s, 10) < 5;
	 // Modifications as compared to original program: avoid overdraw and decompose
	 // the entire image into independent polygons
	 Q(tl, tli, bli, bl, j ? 0xffffffff : 0xff0000ff);   // left red-white border
	 Q(tri, tr, br, bri, j ? 0xffffffff : 0xff0000ff);   // right red-white border
	 Q(tli, tri, bri, bli, j ? 0xff2f2f2f : 0xff3f3f3f); // road
	 // terrain
	 Q(make_vec2(a.x, tl.y), tl, bl, make_vec2(a.x, bl.y), 0xff007f00);
	 Q(tr, make_vec2(b.x,tr.y), make_vec2(b.x,br.y), br, 0xff007f00);
	 
      }
   }
     
}

void main() {
   ImVec2 a = make_vec2(0,0);
   ImVec2 b = make_vec2(320,180);
   ImVec2 d = make_vec2(320,180);
   float  t = 0.0;
   GL_init();

   // Draw sky, only once
   Q(a, make_vec2(b.x, a.y), b, make_vec2(a.x,b.y), 0xffffff00);
   for(;;) {
      FX(a,b,d,t);
      t = t+0.1;
   }
}
