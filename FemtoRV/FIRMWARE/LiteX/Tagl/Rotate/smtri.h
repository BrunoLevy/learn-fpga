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
 * smtri.h
 *
 */

#ifndef SMOOTH_TRI_H
#define SMOOTH_TRI_H

#include "bezier.h"

class SmoothTriangle : public Mesh
{
 public:
  SmoothTriangle(void);
  SmoothTriangle(VectorF P0, VectorF P1, VectorF P2);
  SmoothTriangle(VectorF P0, VectorF P1, VectorF P2, 
		 VectorF N0, VectorF N1, VectorF N2);

  void Update(VectorF P0, VectorF P1, VectorF P2, 
	      VectorF N0, VectorF N1, VectorF N2);

  virtual ~SmoothTriangle(void);


  virtual void RotX(Angle r);
  virtual void RotY(Angle r);
  virtual void RotZ(Angle r);
  virtual void Translate(int tx, int ty, int tz);
  virtual void Scale(double sx, double sy, double sz);

  virtual void Shiny(gfloat factor, gfloat lambertian, gfloat specular);
  virtual void Dull();

  virtual void Draw(PolygonEngine *PE);

  virtual void Lighting(void);

 protected:
  Bezier* _T0;
  Bezier* _T1;
  Bezier* _T2;

};


#endif
