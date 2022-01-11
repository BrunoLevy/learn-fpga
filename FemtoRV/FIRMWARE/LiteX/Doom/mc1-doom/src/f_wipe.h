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
//      Mission start screen wipe/melt, special effects.
//
//-----------------------------------------------------------------------------

#ifndef __F_WIPE_H__
#define __F_WIPE_H__

//
//                       SCREEN WIPE PACKAGE
//

enum
{
    // simple gradual pixel change for 8-bit only
    wipe_ColorXForm,

    // weird screen melt
    wipe_Melt,

    wipe_NUMWIPES
};

int
wipe_StartScreen
( int           x,
  int           y,
  int           width,
  int           height );

int
wipe_EndScreen
( int           x,
  int           y,
  int           width,
  int           height );

int
wipe_ScreenWipe
( int           wipeno,
  int           x,
  int           y,
  int           width,
  int           height,
  int           ticks );

#endif  // __F_WIPE_H__
