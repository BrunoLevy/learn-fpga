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
//      Simple basic typedefs, isolated here to make it easier
//       separating modules.
//
//-----------------------------------------------------------------------------

#ifndef __DOOMTYPE__
#define __DOOMTYPE__

#ifndef __BYTEBOOL__
#define __BYTEBOOL__
// Fixed to use builtin bool type with C++.
#ifdef __cplusplus
typedef bool boolean;
#else
typedef enum {false, true} boolean;
#endif
typedef unsigned char byte;
#endif

#include <limits.h>

// Old <values.h> aliases.

#define MAXCHAR   CHAR_MAX
#define MAXSHORT  SHRT_MAX

// Max pos 32-bit int.
#define MAXINT    INT_MAX
#define MAXLONG   LONG_MAX
#define MINCHAR   CHAR_MIN
#define MINSHORT  SHRT_MIN

// Max negative 32-bit integer.
#define MININT    INT_MIN
#define MINLONG   LONG_MIN

#endif  // __DOOMTYPE__
