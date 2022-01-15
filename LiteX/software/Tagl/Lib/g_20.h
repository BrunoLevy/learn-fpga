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
 * gcompat_20.h
 * 
 * backward compatibility from TAGL 2.1 to 2.0
 *
 */

#ifndef GCOMPAT_20_H
#define GCOMPAT_20_H

// These type names have been changed to avoid
// collision with user types.

typedef GVertex           Vertex;
typedef GVertexPool       VertexPool;
typedef GVertexAttributes VertexAttributes;
typedef GPolygon          Polygon;

// Old virtual constructor

inline GraphicPort* MakeGraphicPort(char* name, 
				    ScrCoord width, ScrCoord height,
				    int verbose_level = MSG_NONE)
{
  return GraphicPort::Make(name, width, height, verbose_level);
}

inline PolygonEngine* MakePolygonEngine(GraphicPort *GP, 
					int verbose_level = MSG_NONE)
{
  return PolygonEngine::Make(GP, verbose_level);
}

#endif
