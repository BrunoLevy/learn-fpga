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
 * gnumbers.h
 *
 */

#ifndef GNUMBERS_H
#define GNUMBERS_H

#include <math.h>
#include "machine.h"

//
// These classes are used to represent GMatrices, GPoints and GVectors.
// They have assembly-like operations. 
// mld = multiply - load
// mac = multiply - accumulate
// msb = multiply - substract
// lod = load
// ldo = load opposite ( = lod(-x) )
// sto = store
// mul = multiply
// div = divide
//
// For the moment, they are floats, but it will be integers later on ...
// They make matrix-vector computation independant from the internal
// representation.
//
// I could have overloaded the operators =, *=, += ..., but I want to
// be sure about what conversions are done, and there is no operator
// for mac, mld, and msb ...
//
// Define GINT for integer math
//

typedef float gfloat;
typedef int   gint;
typedef int   gAngle;


#ifdef GINT

const int GCOEFF_SHIFT = 10;
const int GCOORD_SHIFT = 8;

const gfloat GCOEFF_MUL = (gfloat)(1L << GCOEFF_SHIFT);
const gfloat GCOORD_MUL = (gfloat)(1L << GCOORD_SHIFT);
const gfloat GCOEFF_DIV = 1.0/GCOEFF_MUL;
const gfloat GCOORD_DIV = 1.0/GCOORD_MUL;

typedef int32 ginternal;

#else

const int GCOORD_SHIFT = 8;

typedef float ginternal;

#endif



// Coefficient of a matrix.

class GCoeff
{
 public:

  GCoeff(void);

  void mul(gfloat x);

  void mld(GCoeff x1, GCoeff x2);
  void mld(GCoeff x1, gfloat x2);

  void mac(GCoeff x1, GCoeff x2);
  void mac(GCoeff x1, gfloat x2);
  
  void msb(GCoeff x1, GCoeff x2);

  void lod(GCoeff x);
  void ldo(GCoeff x);
  void lod(gint   x);
  void lod(gfloat x);
  void lod(double x);

  void sto(GCoeff &x);
  void sto(gint   &x);
  void sto(gfloat &x);

  void div(gfloat &x);

  gint   iget(void);
  gfloat fget(void); 

  void   sin(gAngle alpha); // angles are in tenth of degrees
  void   cos(gAngle alpha);
  void   tan(gAngle alpha);
  void   cot(gAngle alpha);

  void   sin(gfloat alpha);
  void   cos(gfloat alpha);
  

  ginternal& data(void);
  void       set(ginternal x);

 private:

  ginternal _x;

  friend class GCoord;
};

// ostream& operator<<(ostream& output, GCoeff x);

// Coordinate

class GCoord
{
 public:
  GCoord(void); 

  void mld(GCoord x1, GCoeff x2);
  void mac(GCoord x1, GCoeff x2);
  
  void mld(GCoord x1, GCoord x2);
  void mac(GCoord x1, GCoord x2);
  void msb(GCoord x1, GCoord x2);

  void sub(GCoord x);

  int  ge(void);

  void lod(GCoord x);
  void lod(gint   x);
  void lod(gfloat x);

  void sto(GCoord &x);
  void sto(gint   &x);
  void sto(gfloat &x);
//  void sto(long  &x);

  void div(GCoord x);

  gint   iget(void);
  gfloat fget(void); 

  ginternal& data(void);
  void       set(ginternal x);

 private:

  ginternal _x;

};

// ostream& operator<<(ostream& output, GCoord x);

#include "gnum.ih"

#endif

