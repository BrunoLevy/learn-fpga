#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <math.h>

#define debug(...)
//#define debug printf

// torus radii and distance from camera
// these are pretty baked-in to other constants now, so it probably won't work
// if you change them too much.
const int dz = 5, r1 = 1, r2 = 2;

// "Magic circle algorithm"? DDA? I've seen this formulation in a few places;
// first in Hal Chamberlain's Musical Applications of Microprocessors, but not
// sure what to call it, or how to justify it theoretically. It seems to
// correctly rotate around a point "near" the origin, without losing magnitude
// over long periods of time, as long as there are enough bits of precision in x
// and y. I use 14 bits here.
#define R(s,x,y) x-=(y>>s); y+=(x>>s)

// CORDIC algorithm to find magnitude of |x,y| by rotating the x,y vector onto
// the x axis. This also brings vector (x2,y2) along for the ride, and writes
// back to x2 -- this is used to rotate the lighting vector from the normal of
// the torus surface towards the camera, and thus determine the lighting amount.
// We only need to keep one of the two lighting normal coordinates.
int length_cordic(int16_t x, int16_t y, int16_t *x2_, int16_t y2) {
  int x2 = *x2_;
  if (x < 0) { // start in right half-plane
    x = -x;
    x2 = -x2;
  }
  for (int i = 0; i < 8; i++) {
    int t = x;
    int t2 = x2;
    if (y < 0) {
      x -= y >> i;
      y += t >> i;
      x2 -= y2 >> i;
      y2 += t2 >> i;
    } else {
      x += y >> i;
      y -= t >> i;
      x2 += y2 >> i;
      y2 -= t2 >> i;
    }
  }
  // divide by 0.625 as a cheap approximation to the 0.607 scaling factor factor
  // introduced by this algorithm (see https://en.wikipedia.org/wiki/CORDIC)
  *x2_ = (x2 >> 1) + (x2 >> 3);
  return (x >> 1) + (x >> 3);
}

void main() {
  // high-precision rotation directions, sines and cosines and their products
  int16_t sB = 0, cB = 16384;
  int16_t sA = 11583, cA = 11583;
  int16_t sAsB = 0, cAsB = 0;
  int16_t sAcB = 11583, cAcB = 11583;

  for (;;) {
    int x1_16 = cAcB << 2;

    // yes this is a multiply but dz is 5 so it's (sb + (sb<<2)) >> 6 effectively
    int p0x = dz * sB >> 6;
    int p0y = dz * sAcB >> 6;
    int p0z = -dz * cAcB >> 6;

    const int r1i = r1*256;
    const int r2i = r2*256;

    int niters = 0;
    int nnormals = 0;
    int16_t yincC = (cA >> 6) + (cA >> 5);      // 12*cA >> 8;
    int16_t yincS = (sA >> 6) + (sA >> 5);      // 12*sA >> 8;
    int16_t xincX = (cB >> 7) + (cB >> 6);      // 6*cB >> 8;
    int16_t xincY = (sAsB >> 7) + (sAsB >> 6);  // 6*sAsB >> 8;
    int16_t xincZ = (cAsB >> 7) + (cAsB >> 6);  // 6*cAsB >> 8;
    int16_t ycA = -((cA >> 1) + (cA >> 4));     // -12 * yinc1 = -9*cA >> 4;
    int16_t ysA = -((sA >> 1) + (sA >> 4));     // -12 * yinc2 = -9*sA >> 4;
    //int dmin = INT_MAX, dmax = -INT_MAX;
    for (int j = 0; j < 23; j++, ycA += yincC, ysA += yincS) {
      int xsAsB = (sAsB >> 4) - sAsB;  // -40*xincY
      int xcAsB = (cAsB >> 4) - cAsB;  // -40*xincZ;

      int16_t vxi14 = (cB >> 4) - cB - sB; // -40*xincX - sB;
      int16_t vyi14 = ycA - xsAsB - sAcB;
      int16_t vzi14 = ysA + xcAsB + cAcB;

      for (int i = 0; i < 79; i++, vxi14 += xincX, vyi14 -= xincY, vzi14 += xincZ) {
        int t = 512; // (256 * dz) - r2i - r1i;

        int16_t px = p0x + (vxi14 >> 5); // assuming t = 512, t*vxi>>8 == vxi<<1
        int16_t py = p0y + (vyi14 >> 5);
        int16_t pz = p0z + (vzi14 >> 5);
        debug("pxyz (%+4d,%+4d,%+4d)\n", px, py, pz);
        int16_t lx0 = sB >> 2;
        int16_t ly0 = sAcB - cA >> 2;
        int16_t lz0 = -cAcB - sA >> 2;
        for (;;) {
          int t0, t1, t2, d;
          int16_t lx = lx0, ly = ly0, lz = lz0;
          debug("[%2d,%2d] (px, py) = (%d, %d), (lx, ly) = (%d, %d) -> ", j, i, px, py, lx, ly);
          t0 = length_cordic(px, py, &lx, ly);
          debug("t0=%d (lx', ly') = (%d, %d)\n", t0, lx, ly);
          t1 = t0 - r2i;
          t2 = length_cordic(pz, t1, &lz, lx);
          d = t2 - r1i;
          t += d;

          if (t > 8*256) {
            putchar(' ');
            break;
          } else if (d < 2) {
            int N = lz >> 9;
            putchar(".,-~:;!*=#$@"[N > 0 ? N < 12 ? N : 11 : 0]);
            nnormals++;
            break;
          }
          // todo: shift and add version of this

          /*
            if (d < dmin) dmin = d;
            if (d > dmax) dmax = d;
            px += d*vxi14 >> 14;
            py += d*vyi14 >> 14;
            pz += d*vzi14 >> 14;
          */
          {
            // 11x1.14 fixed point 3x parallel multiply
            // only 16 bit registers needed; starts from highest bit to lowest
            // d is about 2..1100, so 11 bits are sufficient
            int16_t dx = 0, dy = 0, dz = 0;
            int16_t a = vxi14, b = vyi14, c = vzi14;
            while (d) {
              if (d&1024) {
                dx += a;
                dy += b;
                dz += c;
              }
              d = (d&1023) << 1;
              a >>= 1;
              b >>= 1;
              c >>= 1;
            }
            // we already shifted down 10 bits, so get the last four
            px += dx >> 4;
            py += dy >> 4;
            pz += dz >> 4;
          }

          niters++;
        }
      }
      puts("");
    }
    printf("%d iterations %d lit pixels\x1b[K", niters, nnormals);
//    fflush(stdout);

    // rotate sines, cosines, and products thereof
    // this animates the torus rotation about two axes
    R(5, cA, sA);
    R(5, cAsB, sAsB);
    R(5, cAcB, sAcB);
    R(6, cB, sB);
    R(6, cAcB, cAsB);
    R(6, sAcB, sAsB);

//    usleep(15000);
    printf("\r\x1b[23A");
  }
}
