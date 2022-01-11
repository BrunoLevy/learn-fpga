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
//
//-----------------------------------------------------------------------------

#ifndef __M_MISC__
#define __M_MISC__

#include <stddef.h>

#include "doomtype.h"

//
// MISC
//

boolean
M_WriteFile
( char const*   name,
  void*         source,
  int           length );

int
M_ReadFile
( char const*   name,
  byte**        buffer );

void M_ScreenShot (void);

void M_LoadDefaults (void);

void M_SaveDefaults (void);

int
M_DrawText
( int           x,
  int           y,
  boolean       direct,
  char*         string );

int M_strcmpi (const char* s1, const char* s2);

int M_strncmpi (const char* s1, const char* s2, size_t n);

const char* M_GetHomeDir ();

const char* M_GetDoomWadDir ();

int M_FileExists (const char* name);

#endif  // __M_MISC__
