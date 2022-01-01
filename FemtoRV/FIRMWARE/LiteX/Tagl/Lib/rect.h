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
 * rect.h
 *
 */


#ifndef RECT_H
#define RECT_H

#include "gdefs.h"

class Rect
{

  friend class PolygonEngine;
  friend class LocalGeometryManager;

 protected:
  ScrCoord _x1,_y1,_x2,_y2;
  SZCoord  _z1,_z2;

 public:
  Rect(const ScrCoord x1=0, const ScrCoord y1=0, const ScrCoord x2=0, const ScrCoord y2=0);
  void Set(const ScrCoord x1, const ScrCoord y1, const ScrCoord x2, const ScrCoord y2);
  void Get(ScrCoord *x1, ScrCoord *y1, ScrCoord *x2, ScrCoord *y2) const;

  void Set(const ZCoord z1, const ZCoord z2);
  void Get(ZCoord *z1, ZCoord *z2);
};

#include "rect.ih"

#endif
