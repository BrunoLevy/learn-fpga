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
 * gman.h
 *
 */

// The high level interface to TAGL.

#ifndef GMAN_H
#define GMAN_H

#include "gproc.h"
#include "gmath.h"

// Matrix Mode

typedef int gmmode;

const int GMM_SINGLE    = 0;
const int GMM_PROJECT   = 1;
const int GMM_MODELVIEW = 2;
const int GMM_TEXTURE   = 3;

// Begin-End  mode

typedef int gbemode;

const int GBE_NONE        = 0;
const int GBE_POINTS      = 1;
const int GBE_CLOSED_LINE = 2;
const int GBE_POLYGON     = 3;
const int GBE_QSTRIP      = 4;

// Polygon mode

typedef int gpmode; 

const int GPM_VERTICE     = 0;
const int GPM_EDGES       = 1;
const int GPM_FILL        = 2;

// Culling mode

typedef int gcmode; 

const int GCM_NONE        = 0;
const int GCM_BACKFACE    = 1;
const int GCM_FRONTFACE   = 2;

// Base class for Geometry Managers
// Will be derived into:
// - LocalGeometryManager  = direct output to PolygonEngine/GraphicPort
// - RemoteGeometryManager = transmit calls to a distant screen
// - MacroGeometryManager  = calls are memorized, to be executed later by
//                           a GeometryManager. 

class GeometryManager : public GraphicProcessor
{

 public:

  // Input functions -- This will be replaced by an event queue later on ...
  // These cannot be used in MacroGeometryManager (Display Lists).

  virtual int  WaitEvent(void);
  virtual char GetKey(void);
  virtual int  GetMouse(ScrCoord *x, ScrCoord *y);

  // MacroGeometryManager playback.
  // Cannot be used in Local and RemoteGeometryManagers.

  virtual int Playback(GeometryManager *output);

  // Last error

  virtual Flag ErrorCode(void) = 0;
  
  // Begin-End

  virtual void Begin(gbemode mode) = 0;
  virtual void End(void)          = 0;
  virtual void Vertex(gfloat x, gfloat y, gfloat z) = 0;
  virtual void Vertex(GCoord x, GCoord y, GCoord z) = 0;
  virtual void Normal(gfloat x, gfloat y, gfloat z) = 0;
  virtual void Color (gfloat r, gfloat g, gfloat b) = 0;
  virtual void Color (gint   r, gint   g, gint   b) = 0;
  virtual void Color (gfloat c)                     = 0;
  virtual void Color (gint   c)                     = 0;

  // Graphic Port 

  virtual ScrCoord Width(void);
  virtual ScrCoord Height(void);

  virtual void Clear()          = 0;
  virtual void ZClear(void)     = 0;
  virtual void ZClear(ZCoord z) = 0;

  virtual int  SingleBuffer(void)      = 0;
  virtual int  DoubleBuffer(void)      = 0;
  virtual int  SwapBuffers(void)       = 0;

  virtual void MapColor(const ColorIndex i, 
			const ColorComponent r, 
			const ColorComponent g, 
			const ColorComponent b ) = 0;  

  // Viewport and ScreenMask Management

  virtual void Viewport(ScrCoord left, ScrCoord right, 
			ScrCoord bottom, ScrCoord top) = 0;

  virtual void PushViewport(void) = 0;
  virtual void PopViewport(void)  = 0;

  virtual void ScreenMask(ScrCoord left, ScrCoord right, 
			  ScrCoord bottom, ScrCoord top) = 0;

  virtual void SetDepth(ZCoord _near, ZCoord _far) = 0;

  // Matrix Management

  virtual void MatrixMode(gmmode mode) = 0;
  virtual void PushMatrix(void)        = 0;
  virtual void PopMatrix(void)         = 0;

  virtual void Identity(void)          = 0;

  // Projections

  virtual void Perspective(gAngle _fov, gfloat _aspect, 
			   gfloat _near, gfloat _far) = 0;

  virtual void Ortho(gfloat _left, gfloat _right, gfloat _bottom, gfloat _top, 
		     gfloat _near, gfloat _far) = 0;

  // Viewing

  virtual void PolarView(gfloat dist, gAngle azim, 
			 gAngle inc, gAngle twist) = 0;

  virtual void LookAt(gfloat vx, gfloat vy, gfloat vz,
		      gfloat px, gfloat py, gfloat pz) = 0;

  virtual void LookAt(gfloat vx, gfloat vy, gfloat vz,
		      gfloat px, gfloat py, gfloat pz, 
		      gAngle twist) = 0;

  // Transforming


  virtual void Translate(gfloat x, gfloat y, gfloat z) = 0;
  virtual void Rotate(gAngle r, char axis)             = 0;
  virtual void Scale(gfloat sx, gfloat sy, gfloat sz)  = 0;

  // Matrix I/O

  virtual void LoadMatrix(GMatrix& M) = 0;
  virtual void MultMatrix(GMatrix& M) = 0;
  virtual void GetMatrix(GMatrix&  M) = 0;

  // Operating modes

  virtual void PolygonMode(gpmode mode) = 0;
  virtual void CullingMode(gcmode mode) = 0;
  
};


// GeometryManager& operator<<( GeometryManager& output, 
//			        GeometryManager& data );

#include "gman.ih"

#endif
