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
 * trimesh.h
 *
 */


#ifndef TRIMESH_H
#define TRIMESH_H

#include "mesh.h"

class TriMesh: public Mesh
{
 public:
  TriMesh(VectorF& P0, VectorF& P1, VectorF& P2, int n = 5);
  static int  TIndex(int n, int u, int v);
         int  TIndex(int u, int v);
         void TVertex(int n, VectorF& V, double u, double v, double w, double h);
         void TVertex(VectorF& V, double u, double v, double w, double h);
  MVertex& operator()(int u, int v);

  virtual void RotX(Angle r);
  virtual void RotY(Angle r);
  virtual void RotZ(Angle r);
  virtual void Translate(int tx, int ty, int tz);
  virtual void Scale(double sx, double sy, double sz);

  VectorF& GetP0(void);  
  VectorF& GetP1(void);
  VectorF& GetP2(void);
  VectorF& GetN(void);

 protected:
  VectorF _P0, _P1, _P2;
  VectorF _N;
  int _n;

};

#include "trimesh.ih"

#endif
