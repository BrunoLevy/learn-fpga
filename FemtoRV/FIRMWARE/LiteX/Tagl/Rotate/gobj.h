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
 * gobj.h
 *
 */

#ifndef GOBJ_H
#define GOBJ_H

#include "sintab.h"
#include "gdefs.h"
#include "polyeng.h"
#include "gmath.h"
#include "vectorf.h"

//
// For the moment, GraphicObjects need to implement
// some of the 3Dengine stuff. It is implemented as
// static members. It will be moved to the right
// class later on ...
//


const int SPEC_VALUES = 1024;
const int SPEC_SHIFT  = 4;
const int SPEC_MAX    = SPEC_VALUES << SPEC_SHIFT;

const int GAMMA_VALUES = 1024;
const int GAMMA_SHIFT  = 8;   // 4 for M_BIG + 4 for 16 lamps.
const int GAMMA_MAX    = GAMMA_VALUES << GAMMA_SHIFT;

const Flag GF_NONE     = 0;
const Flag GF_SPECULAR = 1;
const Flag GF_MAX      = GF_SPECULAR;


typedef struct
{
  double r,g,b;
} ColorF;


class MVector
{
 public:
  MVector(int xx = 0, int yy = 0, int zz = 0);
  void Normalize(void);
  void RotX(Angle r);
  void RotY(Angle r);
  void RotZ(Angle r);
  void Rotate(Angle rx, Angle ry, Angle rz);
  void Translate(int tx, int ty, int tz);
  void Scale(double sx, double sy, double sz);
  void Scale(double s);

  MVector& operator<<(VectorF& V);
  
  int x,y,z;
};

// istream& operator >> (istream& input,  MVector& V);
// ostream& operator << (ostream& output, MVector& V);

// VectorF& operator<<(VectorF&, MVector& V);


class MVertex : public MVector
{
 public:
  MVertex(int  x = 0, int y = 0, int z = 0);
  MVector N;
  GVertex  Projection;
  int r,g,b;
  int count;
};




class GraphicObject
{

 public:
  virtual ~GraphicObject();

  Flags& Mode(void);


// Graphic io

  virtual void Draw(PolygonEngine *PE) = 0;


// Transforming

  virtual void RotX(Angle r) = 0;
  virtual void RotY(Angle r) = 0;
  virtual void RotZ(Angle r) = 0;
  void Rotate(char axis, Angle r);
  void Rotate(Angle rx, Angle ry, Angle rz);
  virtual void Translate(int tx, int ty, int tz)      = 0;
  virtual void Scale(double sx, double sy, double sz) = 0;
  void Scale(double s);

// Illumination model

  static  void GammaRamp(gfloat gamma);
  virtual void Lighting(void) = 0;
  virtual void ResetColors(void) = 0;

  int Specular(int x);  // x = 0..M_BIG
  int Gamma(int x);     // x = 0..M_BIG

// Material properties

  virtual void Shiny(gfloat factor, gfloat lambertian, gfloat specular);
  virtual void Dull();

// Global transformation and lighting model

  static void SetGeometry(int width, int height);

  static void SetLightDirection(int  Lx, int  Ly, int  Lz);
  static void GetLightDirection(int *Lx, int *Ly, int *Lz);

  static void SetLightColor(int  Lr, int  Lg, int  Lb);
  static void GetLightColor(int *Lr, int *Lg, int *Lb);

  static void SetLightColor(int  Lc);
  static void GetLightColor(int *Lc);

  static void SetZoom(int  zoom);
  static int  GetZoom(void);
  static void SetZoomStep(int zoom_step);
  static int  GetZoomStep(void);
  static void ZoomIn(void);
  static void ZoomOut(void);
  static MVector& LightDirection(void);

 protected:

  static void Project(MVertex *V);

  static int _width;
  static int _height;
  static MVector _L;
  static int _Lr, _Lg, _Lb;
  static int _Lc;

  static int _zoom;
  static int _zoom_step;

  Flags _flags;

  static int _gamma_ramp[GAMMA_VALUES];
                              // pre-computed gamma ramp

  int        _specular[SPEC_VALUES]; 
                              // pre-computed powers of numbers between 0 and 1
                              // allows quick evaluation of Phong lighting model.
 
  int _KS;                    // specular factor
  int _KD;                    // diffuse factor

};

// PolygonEngine* operator << (PolygonEngine* output, GraphicObject& O);

#include "gobj.ih"

#endif
