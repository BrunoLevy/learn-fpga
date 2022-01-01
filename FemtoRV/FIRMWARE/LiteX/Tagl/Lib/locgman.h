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
 * locgman.h
 *
 */

// A geometry manager that outputs data to a GraphicPort

#ifndef LOCGMAN_H
#define LOCGMAN_H

#include "gman.h"
#include "gport.h"
#include "polyeng.h"
#include "vpool.h"

const Flag GMR_NONE    = 0;
const Flag GMR_GPORT   = 1;
const Flag GMR_POLYENG = 2;

const Flag GME_OK      = 0;
const Flag GME_GPORT   = 1;
const Flag GME_POLYENG = 2;

const Flag GMM_NONE    = 0;
const Flag GMM_ISO     = 1;

class LocalGeometryManager : public GeometryManager
{

 public:

  virtual void CommitAttributes(void);

  // Constructor

  LocalGeometryManager(char *name, ScrCoord width, ScrCoord height, 
		       int verbose_level = MSG_ENV);

  // Destructor

  virtual ~LocalGeometryManager(void);

  // Input functions -- This will be replaced by an event queue later on ...
  // These cannot be used in MacroGeometryManager (Display Lists).

  virtual int  WaitEvent(void);
  virtual char GetKey(void);
  virtual int  GetMouse(ScrCoord *x, ScrCoord *y);


  // Last error

  virtual Flag ErrorCode(void);

  // Begin-End

  virtual void Begin(gbemode mode);
  virtual void End(void);
  virtual void Vertex(gfloat x, gfloat y, gfloat z);
  virtual void Vertex(GCoord x, GCoord y, GCoord z);
  virtual void Normal(gfloat x, gfloat y, gfloat z);
  virtual void Color (gfloat r, gfloat g, gfloat b);
  virtual void Color (gint   r, gint   g, gint   b);
  virtual void Color (gfloat c);
  virtual void Color (gint   c);

  // Graphic Port 

  virtual void Clear();
  virtual void ZClear(void);
  virtual void ZClear(ZCoord z);

  virtual int  SingleBuffer(void);
  virtual int  DoubleBuffer(void);
  virtual int  SwapBuffers(void);

  virtual void MapColor(const ColorIndex i, 
			const ColorComponent r, 
			const ColorComponent g, 
			const ColorComponent b );

  virtual ScrCoord Width(void);
  virtual ScrCoord Height(void);

  // Viewport and ScreenMask Management

  virtual void Viewport(ScrCoord left, ScrCoord right, 
			ScrCoord bottom, ScrCoord top);

  virtual void PushViewport(void);
  virtual void PopViewport(void);

  virtual void ScreenMask(ScrCoord left, ScrCoord right, 
			  ScrCoord bottom, ScrCoord top);

  virtual void SetDepth(ZCoord _near, ZCoord _far);

  // Matrix Management

  virtual void MatrixMode(gmmode mode);
  virtual void PushMatrix(void);
  virtual void PopMatrix(void);

  virtual void Identity(void);

  // Projections

  virtual void Perspective(gAngle _fov, gfloat _aspect, 
			   gfloat _near, gfloat _far);

  virtual void Ortho(gfloat _left, gfloat _right, gfloat _bottom, gfloat _top, 
		     gfloat _near, gfloat _far);

  // Viewing

  virtual void PolarView(gfloat dist, gAngle azim, 
			 gAngle inc, gAngle twist);

  virtual void LookAt(gfloat vx, gfloat vy, gfloat vz,
		      gfloat px, gfloat py, gfloat pz);

  virtual void LookAt(gfloat vx, gfloat vy, gfloat vz,
		      gfloat px, gfloat py, gfloat pz, 
		      gAngle twist);

  // Transforming


  virtual void Translate(gfloat x, gfloat y, gfloat z);
  virtual void Rotate(gAngle r, char axis);
  virtual void Scale(gfloat sx, gfloat sy, gfloat sz);

  // Matrix I/O

  virtual void LoadMatrix(GMatrix& M);
  virtual void MultMatrix(GMatrix& M);
  virtual void GetMatrix(GMatrix&  M);


  // Operating modes

  virtual void PolygonMode(gpmode mode);
  virtual void CullingMode(gcmode mode);

 protected:

  GMatrix& GetModelView(void);
  GMatrix& GetProject(void);
  GMatrix& GetTexture(void);
  Rect&    GetViewport(void);
  GMatrix& GetSingle(void); 

  ScrCoord GetWidth(void);
  ScrCoord GetHeight(void);

  GVertexAttributes& VAttributes(void);

  void CommitViewport(void);
  void CommitSingle(void); 

  void DoPoints(void);
  void DoClosedLine(void);
  void DoPolygon(void);

 private:
  
  Flags          _resources;
  GraphicPort*   _graphic_port;
  PolygonEngine* _polygon_engine;

  GMatrix        _project;
  GMatrix        _project_viewport;

  GMatrix        _stack_modelview[ATTRIB_STACK_SZ];
  int            _stack_modelview_idx;

  Rect           _stack_viewport[ATTRIB_STACK_SZ];
  int            _stack_viewport_idx;

  GMatrix        _stack_single[ATTRIB_STACK_SZ];
  int            _stack_single_idx; 
   
  GMatrix        _texture;

  Flag           _error_code;

  GVertexPool    _vpool;
  GVertex        _qstrip_pool[4];
  int            _qstrip_idx;
  int            _qstrip_nbr;

  gbemode        _be_mode;
  gmmode         _m_mode;
  gpmode         _poly_mode;
  gcmode         _culling_mode;
   
  friend class ES_IndexedMesh;
};

#include "locgman.ih"

#endif
