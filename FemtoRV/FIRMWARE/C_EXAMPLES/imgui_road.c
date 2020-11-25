/*
 * Grabbed and adapted from the demos from the ImGUI demos contest:
 * https://github.com/ocornut/imgui/issues/3606
 */ 
#include "imgui_emul.h"

void FX(ImVec2 a, ImVec2 b, ImVec2 d, float t) {
   static float cz = 0;
   static bool first = true;
   if(first) {
      // Draw sky, only once
      addQuad(a, vec2(b.x, a.y), b, vec2(a.x,b.y), 0xffffff00);
      first = false;
   }
   
   ImVec2 bl = vec2(160, 90), br = bl, bri = bl, bli = bl;
   cz += 0.5f;
   // addQuad(a, vec2(b.x, a.y), vec2(b.x, a.y + 30), vec2(a.x, a.y + 30), 0xffffff00);
   // addQuad(vec2(a.x, a.y + 30), vec2(b.x, a.y + 30), b, vec2(a.x, b.y), 0xff007f00);
   
   // Normally the loop goes from 300 -> 0, reduced it: 30 -> 0 because floating point ops
   // take too much time (it changes the result a bit but still OK)
   for (int s = 30; s > 0; s--) {
      float c = sinf((cz + s) * 0.1f) * 500;
      float f = cosf((cz + s) * 0.02f) * 1000;
      ImVec2 tl = bl, tr = br, tli = bli, tri = bri;
      tli.y--;
      tri.y--;
      float ss = 0.003f / s;
      float w = 2000 * ss * 160;
      float px = a.x + 160 + (f * ss * 160);
      float py = 90 - (ss * (c * 2 - 2500) * 90);
      bl = vec2(px - w, py);
      br = vec2(px + w, py);
      w = 1750 * ss * 160;
      bli = vec2(px - w, py);
      bri = vec2(px + w, py);
      if (s != 300) {
	 bool j = fmodf(cz + s, 10) < 5;
	 // Modifications as compared to original program: avoid overdraw and decompose
	 // the entire image into independent polygons
	 addQuad(tl, tli, bli, bl, j ? 0xffffffff : 0xff0000ff);   // left red-white border
	 addQuad(tri, tr, br, bri, j ? 0xffffffff : 0xff0000ff);   // right red-white border
	 addQuad(tli, tri, bri, bli, j ? 0xff2f2f2f : 0xff3f3f3f); // road
	 // terrain
	 addQuad(vec2(a.x, tl.y), tl, bl, vec2(a.x, bl.y), 0xff007f00);
	 addQuad(tr, vec2(b.x,tr.y), vec2(b.x,br.y), br, 0xff007f00);
      }
   }
}

