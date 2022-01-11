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
//      Refresh module, drawing LineSegs from BSP.
//
//-----------------------------------------------------------------------------

#ifndef __R_SEGS__
#define __R_SEGS__

void
R_RenderMaskedSegRange
( drawseg_t*    ds,
  int           x1,
  int           x2 );

#endif  // __R_SEGS__
