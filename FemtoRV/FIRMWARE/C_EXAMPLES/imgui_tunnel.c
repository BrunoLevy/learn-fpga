/*
 * Grabbed and adapted from the demos from the ImGUI demos contest:
 * https://github.com/ocornut/imgui/issues/3606
 */ 
#include "imgui_emul.h"

// TODO: * crashes (probably with an FPE, not supported by FemtoRV32)
//       * color is not correct. 


ImVec2 conv(ImVec2 v, float z, ImVec2 sz, ImVec2 o) {
  return vec2_add(vec2((v.x/z)*sz.x*5.f+sz.x*0.5f,(v.y/z)*sz.y*5.f+sz.y*0.5f),o);
}

ImVec2 R(ImVec2 v, float ng) {
  ng*=0.1f;
  return vec2(v.x*cosf(ng)-v.y*sinf(ng),v.x*sinf(ng)+v.y*cosf(ng));
}

void FX(ImVec2 o, ImVec2 b, ImVec2 sz, float t){
  t*=4;
  for (int i = 0; i < 20; i++) {
    float z=21.-i-(t-floorf(t))*2.;
    float ng=-t*2.1+z;
    float ot0=-t+z*0.2;
    float ot1=-t+(z+1.)*0.2;
    float os=0.3;
    ImVec2 s[2]={
	    vec2(cosf((t+z)*0.1)*0.2+1.,sinf((t+z)*0.1)*0.2+1.),
	    vec2(cosf((t+z+1.)*0.1)*0.2+1.,sinf((t+z+1.)*0.1)*0.2+1.)
    };
    ImVec2 of[2]={
	    vec2(cosf(ot0)*os,sinf(ot0)*os),
	    vec2(cosf(ot1)*os,sinf(ot1)*os)
    };
    ImVec2 p[4]={vec2(-1,-1),vec2(1,-1),vec2(1,1),vec2(-1,1)};
    ImVec2 pts[8];
    int j;
    for (j=0;j<8;j++){
      int n = (j/4);
      pts[j]= conv(
	R(vec2_add(vec2_mul(p[j%4],s[n]),of[n]),ng+n),
	(z+n)*2.,
	sz,o
      );
    }
    for (j=0;j<4;j++){
      ImVec2 q[4]={pts[j],pts[(j+1)%4],pts[((j+1)%4)+4],pts[j+4]};
      float it=(((i&1)?0.5:0.6)+j*0.05)*((21.-z)/21.);
      int g = (int)(sqrt(it) * 255.0);
      int rgb = GL_RGB(g,g,g); 
      addQuad(q[0], q[1], q[2], q[3], rgb);
    }
  }
}
