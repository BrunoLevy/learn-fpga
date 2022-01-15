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
//      Endianess handling, swapping 16bit and 32bit.
//
//-----------------------------------------------------------------------------

#ifndef __M_SWAP__
#define __M_SWAP__

// Endianess handling.
// WAD files are stored little endian.
#ifdef __BIG_ENDIAN__
short   SwapSHORT(short);
long    SwapLONG(long);
#define SHORT(x)        ((short)SwapSHORT((unsigned short) (x)))
#define LONG(x)         ((long)SwapLONG((unsigned long) (x)))
#else
#define SHORT(x)        (x)
#define LONG(x)         (x)
#endif

#endif  // __M_SWAP__
