// Emacs style mode select   -*- C++ -*-
//-----------------------------------------------------------------------------
//
// Copyright (C) 1993-1996 by id Software, Inc.
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// DESCRIPTION:
//      System specific interface stuff.
//
//-----------------------------------------------------------------------------

#ifndef __R_MAIN__
#define __R_MAIN__

#include "d_player.h"
#include "r_data.h"

//
// POV related.
//
extern fixed_t          viewcos;
extern fixed_t          viewsin;

extern int              viewwidth;
extern int              viewheight;
extern int              viewwindowx;
extern int              viewwindowy;

extern int              centerx;
extern int              centery;

extern fixed_t          centerxfrac;
extern fixed_t          centeryfrac;
extern fixed_t          projection;

extern int              validcount;

extern int              linecount;
extern int              loopcount;

//
// Lighting LUT.
// Used for z-depth cuing per column/row,
//  and other lighting effects (sector ambient, flash).
//

// Lighting constants.
// Now why not 32 levels here?
#define LIGHTLEVELS             16
#define LIGHTSEGSHIFT            4

#define MAXLIGHTSCALE           48
#define LIGHTSCALESHIFT         12
#define MAXLIGHTZ              128
#define LIGHTZSHIFT             20

extern lighttable_t*    scalelight[LIGHTLEVELS][MAXLIGHTSCALE];
extern lighttable_t*    scalelightfixed[MAXLIGHTSCALE];
extern lighttable_t*    zlight[LIGHTLEVELS][MAXLIGHTZ];

extern int              extralight;
extern lighttable_t*    fixedcolormap;

// Number of diminishing brightness levels.
// There a 0-31, i.e. 32 LUT in the COLORMAP lump.
#define NUMCOLORMAPS            32

//
// Function pointers to switch refresh/drawing functions.
// Used to select shadow mode etc.
//
extern void             (*colfunc) (void);

//
// Utility functions.
int
R_PointOnSide
( fixed_t       x,
  fixed_t       y,
  node_t*       node );

int
R_PointOnSegSide
( fixed_t       x,
  fixed_t       y,
  seg_t*        line );

angle_t
R_PointToAngle
( fixed_t       x,
  fixed_t       y );

angle_t
R_PointToAngle2
( fixed_t       x1,
  fixed_t       y1,
  fixed_t       x2,
  fixed_t       y2 );

fixed_t
R_PointToDist
( fixed_t       x,
  fixed_t       y );

fixed_t R_ScaleFromGlobalAngle (angle_t visangle);

subsector_t*
R_PointInSubsector
( fixed_t       x,
  fixed_t       y );

void
R_AddPointToBox
( int           x,
  int           y,
  fixed_t*      box );

//
// REFRESH - the actual rendering functions.
//

// Called by G_Drawer.
void R_RenderPlayerView (player_t *player);

// Called by startup code.
void R_Init (void);

// Called by M_Responder.
void R_SetViewSize (int blocks);

#endif  // __R_MAIN__
