/*
 * Grabbed and adapted from the demos from the ImGUI demos contest:
 * https://github.com/ocornut/imgui/issues/3606
 */ 
#include "imgui_emul.h"
#include <stdlib.h>

// TODO: * polygon sorting does not seem to be always correct
//           (not sure about how I call qsort())
//       * GL_fill_poly() sometimes generates a line that extends 
//         towards the right edge of the screen.
//       * color is not correct.
//       * drawing background quads does not work.
//       * too slow on the FemtoRV32.

static inline float L(float d,float s) { 
   d*=(d>0);
   return sqrt(1.0-exp(-s*(d+.1)-d*d*d));
}

static inline void R(float* x, float* y, float r) {
  float s=sin(r); 
  float c=cos(r); 
  float t=c*(*x) - s*(*y);
  *y=s*(*x)+c*(*y);
  *x=t;
}

float x,y,z,e,f,g,l;

void T(float u, float t) { 
   R(&x,&z,t/3+u);
   R(&x,&y,t);
   R(&y,&z,t/5);
}

struct Q {
  float d,l;
  ImVec2 o[4];
};

int compare_Q(const void* q1, const void* q2) {
  return(((struct Q*)q1)->d > ((struct Q*)q2)->d);
}
    

void FX(ImVec2 a,ImVec2 b, ImVec2 S,float t) {
  GL_clear();
  int n=0,i,j,k,u,v,K=7,J=16;
  char P[]="GZHXITGPBMBCGA",*X=P;
  ImVec2 m = vec2_scale(vec2_add(a,b),0.5);
  struct Q q[99];
  for(k=K;--k;) {
    X+=2;
    for(j=J;j--;) {
      struct Q* o=&(q[n++]);
      o->d=0;
      for(i=4;i--;){
	u=j+(i%3>0);
	v=-(i/2)*2;
	x=X[v]-65;
	y=77-X[v+1];
	z=0;
	T(IM_PI*2*u/J,t);
	e=x;f=y;
	o->d+=z=S.y/(g=z+40);
	o->o[i]=vec2_add(m,vec2_scale(vec2(x,y),z));
      }
      x=X[1]-X[-1];
      y=*X-X[-2];
      z=0;
      l=sqrt(x*x+y*y);
      T(IM_PI*2*(j+.5)/J,t);
      o->l=((x*e+y*f+z*g)>0?1:-1)*y/l;
    }
  }
  qsort(q, n, sizeof(struct Q), compare_Q);
  /* 
  for(i=99;i--;) {
    b.y=a.y;
    a.y=m.y+9e2/(float)(i+1);
    addRectFilled(a,b,i>97?0xffffd050:0xff608000+(i/9&1)*64+i*65793);
  }
  */
  GL_fill_rect(0,0,GL_width-1,GL_height/2,GL_RGB(0,127,255));
  GL_fill_rect(0,GL_height/2,GL_width-1,GL_height-1,GL_RGB(0,127,0));  
   
  for(i=0;i<n;i++){
    struct Q* o=&(q[i]);l=o->l;
    float r = L(l,0.1);
    float g = L(l,0.3);
    float b = L(l,1.0);
    GL_polygon_mode(GL_POLY_FILL);
    addQuad(o->o[0],o->o[1],o->o[2],o->o[3],GL_RGB_f(r,g,b));
    GL_polygon_mode(GL_POLY_LINES);
    addQuad(o->o[0],o->o[1],o->o[2],o->o[3],0);
  }
  UART_putchar(4); // send <ctrl><D> to UART (exits simulation)
  delay(250);
}
