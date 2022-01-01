/*
 * This software is copyrighted as noted below.  It may be freely copied,
 * modified, and redistributed, provided that the copyright notice is
 * preserved on all copies.
 *
 * There is no warranty or other guarantee of fitness for this software,
 * it is provided solely "as is".  Bug reports or fixes may be sent
 * to the author, who may or may not act on them as he desires.
 *
 * You may not include this software in a program or other software product
 * without supplying the source, or without informing the end-user that the
 * source is available for no extra charge.
 *
 * If you modify this software, you should include a notice giving the
 * name of the person performing the modification, the date of modification,
 * and the reason for such modification.
 *
 * Author:      Bruno Levy
 *
 * Copyright (c) 1996, Bruno Levy.
 *
 */
/*
 *
 * gdefs.h
 *
 */

#ifndef GDEFS_H
#define GDEFS_H

#include <assert.h>
#include <stdio.h>
#include "flags.h"
#include "gmath.h"
#include "machine.h"

const int  GP_COLORMAP_SZ = 256;

typedef int32  ScrCoord;       // coordinates in screen space
typedef uint32 UScrCoord;
typedef uint8  ColorIndex;     // used by colormap  displays
typedef int32  ColorCode;      // used by truecolor displays
typedef uint32 UColorCode;     // unsigned color code
typedef uint16 ZCoord;         // type of a ZBuffer cell
typedef int32  SZCoord;        // used to compute ZBuffer values
typedef int32  TexCoord;       // coordinates in texture space
typedef int32  ColorComponent; // value of R, G, or B
typedef int32  HCoord;         // Homogenous factor

const Flag VF_NONE = 0;
const Flag VF_CLIP = 1;
const Flag VF_WDIV = 2;

class GVertexAttributes
{
 public:
  SZCoord        z;
  ColorCode      c;
  ColorComponent r,g,b,a;
  TexCoord       X,Y;
  HCoord         w;
};

class GVertex : public GVertexAttributes
{
 public:
  ScrCoord       x,y;

  GVector        initial_position;
  GVector        modelview_position;
  GVector        project_position;

  GVector        initial_normal;
  GVector        modelview_normal;

  Flags          flags;
};

class GTexel
{
 public:
   GTexel(void);
   GTexel(ColorComponent r_, ColorComponent g_, ColorComponent b_, ColorComponent a_);
   uint8 b;
   uint8 g;
   uint8 r;
   uint8 a;
};

/*
inline ostream& operator<<(ostream& o, GVertex& v)
{
  return o << "[" << v.x << " " << v.y << " " << v.z << "]\n";
}
*/

const int VC_ENTRIES = 50;

inline void printb(UColorCode x)
{
  int shift;

  for(shift = 31; shift >= 0; shift--)
    fprintf(stderr,x & (((UColorCode)1) << shift) ? "1" : "0");
}

inline int firstbit(UColorCode x)
{
  int cnt;

  for(cnt=0; (cnt < 32) && !(x & (((UColorCode)1) << cnt)); cnt++);

  return cnt;
}

inline int nbrbits(UColorCode x)
{
  int cnt = 0, shift;

  for(shift = 0; shift < 32; shift++)
    if(x & (((UColorCode)1) << shift))
      cnt++;

  return cnt;
}


inline
GTexel::GTexel(void)
{
}

inline
GTexel::GTexel(ColorComponent r_, ColorComponent g_, ColorComponent b_, ColorComponent a_)
{
   r = (uint8)r_;
   g = (uint8)g_;
   b = (uint8)b_;
   a = (uint8)a_;   
}

#endif

