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
 * smmesh.h
 *
 */

#ifndef SMOOTH_MESH
#define SMOOTH_MESH

#include "mesh.h"
#include "smtri.h"

const Flag SMR_FACE = MR_MAX + 1;
const Flag SME_TRI  = ME_MAX + 1;

class SmoothMesh : public Mesh
{
 public:
  SmoothMesh(Mesh *m);
  virtual ~SmoothMesh(void);

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
  SmoothTriangle* _sm_face;
  int             _n_sm_face;

};

#endif
