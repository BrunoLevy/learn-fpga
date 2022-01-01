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
 * mesh.h
 * 
 */


#ifndef MESH_H
#define MESH_H


#include "flags.h"
#include "gobj.h"
#include <libfatfs/ff.h>

const Flag MR_NONE     = 0;
const Flag MR_VERTICES = 1;
const Flag MR_FACES    = 2;
const Flag MR_COLORS   = 3;
const Flag MR_SMOOTH   = 4;
const Flag MR_BLEND    = 5;
const Flag MR_MAX      = MR_BLEND;

const Flag ME_NONE   = 0;
const Flag ME_MALLOC = 1;
const Flag ME_EOF    = 2;
const Flag ME_SNTX   = 3;
const Flag ME_MATCH  = 4;
const Flag ME_MAX    = ME_MATCH;

const Flag MF_NONE      = 0;
const Flag MF_CONVEX    = GF_MAX + 1;
const Flag MF_CLOSED    = GF_MAX + 2;
const Flag MF_SMOOTH    = GF_MAX + 3;
const Flag MF_BLEND     = GF_MAX + 3;
const Flag MF_COLOR     = GF_MAX + 4;
const Flag MF_WIREFRAME = GF_MAX + 5;
const Flag MF_MAX       = MF_WIREFRAME;

class MFace
{
 public:
  MFace(void);
  ~MFace(void);

  int        nvertex;
  MVertex  **vertex;
  MVector   N;

  ColorComponent  r,  g,  b;
  ColorComponent or_, og, ob;
  ColorCode      c;
};

class Mesh : public GraphicObject
{

 public:
  Mesh(void);

 private:
  Mesh(const Mesh& m);
  Mesh& operator=(const Mesh& m);

 public:
  virtual ~Mesh(void);
  virtual void RotX(Angle r);
  virtual void RotY(Angle r);
  virtual void RotZ(Angle r);
  virtual void Translate(int tx, int ty, int tz);
  virtual void Scale(double sx, double sy, double sz);
  virtual void Draw(PolygonEngine *PE);
  virtual void Lighting(void);
  virtual void ResetColors(void);

  Flag   ErrorCode(void);
  Flags& Resources(void);

  void Setup(PolygonEngine *PE);

  void Smooth(void);
  void Blend(void);
  void White(void);
   
  void InvertNormals(void);

  void ComputeNormals(void);

  void EnvironMap(void);
  void TextureMap(char axis, float mult);
   
  MVertex*& Vertex(void);
  int&      NVertex(void);
  MFace*&   Face(void);
  int&      NFace(void);

  void load_geometry(const char* filename);
  void load_colors(const char* filename);
   
 protected:
  int InFace(MFace *F, MVertex *V);

  MVertex*   _vertex;
  int        _nvertex;
  MFace*     _face;
  int        _nface;

  Flags _resources;
  Flag  _error_code;

   
  friend class SmoothMesh;
  friend int check_eof(FIL& input,  Mesh& M);
};


#include "mesh.ih"

#endif
