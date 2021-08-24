/*
 * Grabbed and adapted from the demos from the ImGUI demos contest:
 * https://github.com/ocornut/imgui/issues/3606
 */ 
#include "imgui_emul.h"

void R(float* x, float* y, float r){
  float s=sin(r), c=cos(r);
  float t=c * *x - s* *y;
  *y = s * *x + c * *y;
  *x = t;
}

float c,e,f,g,l,r,x,y,z;
int i,j,k,u,v,K=24,J=48;

float L(float a) {
  l*=l>0;return sqrt(1-exp(-a*(l+.1)-l*l*l));
}

void T(float u){
  R(&x,&z,c+6.28*u);
}

ImVec2 P(float t) {
  t*=3.14/K; return vec2(sin(t),cos(t));
}

// Clearly, femtorv32 is too slow for doing all this math...
void FX(ImVec2 a, ImVec2 b, ImVec2 S, float t) {
  ImVec2 I = vec2(0,0);
  ImVec2 o[4];
  ImVec2 m = vec2(0.5*(a.x+b.x), 0.5*(a.y+b.y));

  c = t/2;
  k=sin(t*13)*24+24;
  j=-0xafefb0+k*0x101;
  float R,G,B;
  
  for(k=K;--k;){
    for(j=J;j--;) {
      for(i=4;i--;) {
	u=j+(i%3>0);v=-(i/2);
	ImVec2 p=P(k+v);
	x=p.x; y=p.y; z=0;
	T((float)u/J); e=x; f=y; z=S.y/(g=z+2.5);
	o[i].x=m.x+x*z;
	o[i].y=m.y+y*z;	
      }
      ImVec2 v1=P(k),v2=P(k-1);
      x=v1.y-v2.y; y=v2.x-v1.x; z=0;
      l=sqrt(x*x+y*y); x=x/l; y=y/l; T((j+.5)/J);
      r=2*(x*e+y*f+z*g);
      e-=r*x;f-=r*y;g-=r*z;
      l=sqrt(e*e+f*f+g*g);
      x=atan2(e,g);y=atan2(sqrt(e*e+g*g),f);
      l=sin(x*5+sin(y*3+t))+sin(x*9+sin(y*5+t))+cos(y*4+sin(x*5+t));
      l=l/4+.5;
      R=l; G=l*.9*(.8+e/4); B=(.5-f/2)*l/2; 
      if(r>0) {
	addQuad(o[0], o[1], o[2], o[3], GL_RGB_f(R,G,B));
      }
    }
  }
}

