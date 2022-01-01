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
 * bezier.h
 *
 */


#ifndef BEZIER_H
#define BEZIER_H

#include "trimesh.h"

const Flag BF_CONTROL = MF_MAX + 1;
const Flag BF_PATCH   = MF_MAX + 2;
const Flag BF_BASE    = MF_MAX + 3;
const Flag BF_MAX     = BF_BASE;

typedef double bnumber;

class Bezier : public TriMesh
{
 public:

  Bezier(
	 VectorF& P0, VectorF& P1, VectorF& P2,
	 bnumber *b = NULL,
	 int degree = 3,
	 int n = 5,
         int control = 1
	 );

  virtual ~Bezier(void);

  void Update(bnumber *b);
  void Update(VectorF *b);
  void Update(VectorF& P0, VectorF& P1, VectorF& P2);

  void FlatControl(VectorF *b);

  virtual void RotX(Angle r);
  virtual void RotY(Angle r);
  virtual void RotZ(Angle r);
  virtual void Translate(int tx, int ty, int tz);
  virtual void Scale(double sx, double sy, double sz);

  virtual void Draw(PolygonEngine *PE);

  void DegreeElevation(VectorF *b_in, VectorF *b_out);

 protected:

  int _degree;

  bnumber   Bernstein(int i, int j, int k, bnumber u, bnumber v, bnumber w);
  bnumber   Bernstein(int n, int i, int j, int k, 
		      bnumber u, bnumber v, bnumber w);
  bnumber   BezierPoly(bnumber *b, bnumber u, bnumber v, bnumber w);
  VectorF   BezierPoly(VectorF *b, bnumber u, bnumber v, bnumber w);
  VectorF  DaBezier(VectorF *b, bnumber u,  bnumber v,  bnumber w,
		                bnumber a1, bnumber a2, bnumber a3);    
  VectorF  Normal(VectorF *b, bnumber u, bnumber v, bnumber w);

  TriMesh *_control;

};


#include "bezier.ih"

#endif

