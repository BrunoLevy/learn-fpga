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
 * gvector.h
 *
 */

#ifndef GVECTOR_H
#define GVECTOR_H

#ifndef GMTX_H
#include "gmatrix.h"
#endif

class GVector
{
 public:
  GVector& operator= (const GVector& V);
  GVector(const GVector& V);
  GVector(void);

// Initialize

  void PointLoadZero(void);
  void VectorLoadZero(void);

// Vector-Matrix product.

  void mld(GVector &V, GMatrix &M);
  void mul(GMatrix &M); // Post-multiply

// Direct access.

  GCoord& operator()(int i);

 private:
  GCoord _x[4];

};

#include "gvector.ih"

#endif
