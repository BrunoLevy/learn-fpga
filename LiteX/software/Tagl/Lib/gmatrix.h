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
 * gmatrix.h
 *
 */

#ifndef GMTX_H
#define GMTX_H


// Some linear algebra ...
// Here are classes for matrices and vectors.

#include "gnum.h"


class GMatrix
{
 public:
  GMatrix& operator= (const GMatrix& M);
  GMatrix(const GMatrix& M);
  GMatrix(void);


// Initialize

  void LoadZero(void);
  void LoadIdentity(void);

// Projections

  void LoadPerspective(gAngle _fov, gfloat _aspect, gfloat _near, gfloat _far);
  void LoadOrtho(gfloat _left, gfloat _right, gfloat _bottom, gfloat _top, 
                 gfloat _near, gfloat _far);

// Transformations (premultiply)

  void Translate(gfloat x, gfloat y, gfloat z);
  void Rotate(gAngle r, char axis);
  void Scale(gfloat sx, gfloat sy, gfloat sz);

// Viewing transformations (premultiply)

  void PolarView(gfloat dist, gAngle azim, gAngle inc, gAngle twist);
  void LookAt(gfloat vx, gfloat vy, gfloat vz,
              gfloat px, gfloat py, gfloat pz);
  void LookAt(gfloat vx, gfloat vy, gfloat vz,
              gfloat px, gfloat py, gfloat pz, 
              gAngle twist);

  
// Matrix level operations

  void mld(GMatrix &M1, GMatrix&M2);
  void mul(GMatrix &M);               // pre-multiply.

// Direct access

  GCoeff& operator()(int i, int j);


 private:
  GCoeff _x[4][4];

};

#include "gmatrix.ih"
#include "gproject.ih"
#include "gtrans.ih"
#include "gview.ih"

#endif

