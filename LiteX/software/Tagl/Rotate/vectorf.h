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
 * vectorf.h
 *
 */

#ifndef VECTORF_H
#define VECTORF_H

#include "sintab.h"

const int M_BIG   = 16384;  // Internal representation of 1.0 (fixed point).
const int M_SHIFT = 14;     // Shift for integer part.
const double SIN_DIV = (double)1.0/(double)((long)1 << SIN_SHIFT);
const double M_DIV   = (double)1.0/(double)M_BIG;
const double M_MUL   = (double)M_BIG;

 
class VectorF
{
 public:

  VectorF(double xx, double yy, double zz);
  VectorF(void);
  VectorF(double xx);
  VectorF& operator=(double xx);
  VectorF& operator=(const VectorF& V);
  int      operator==(double xx);
  double Length(void);
  double Length2(void);  

  void Normalize(void);
  void RotX(Angle r);
  void RotY(Angle r);
  void RotZ(Angle r);
  void Rotate(Angle rx, Angle ry, Angle rz);
  void Translate(int tx, int ty, int tz);
  void Scale(double sx, double sy, double sz);
  void Scale(double s);

  VectorF& operator += (const VectorF& V);
  VectorF& operator -= (const VectorF& V);
  VectorF& operator *= (double a);
  VectorF& operator /= (double a);

  double x,y,z;
};

// VectorF operator+(const VectorF& V1, const VectorF& V2);
// VectorF operator-(const VectorF& V1, const VectorF& V2);
// VectorF operator*(double a, VectorF V);
// VectorF operator/(const VectorF& V, double a);
// double  operator*(const VectorF& V1, const VectorF& V2); 
// VectorF operator^(const VectorF& V1, const VectorF& V2);

// ostream& operator << (ostream& output, const VectorF& V);

#include "vectorf.ih"

#endif
