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
//      Fixed point implementation.
//
//-----------------------------------------------------------------------------

#include <stdlib.h>

#include "doomtype.h"

#include "m_fixed.h"

//
// FixedDiv
//
// Methods:
//   1: long long (slow on most 32-bit machines, accurate)
//   2: float (fast on MRISC32 with an FPU, but inaccurate - demos go wrong)
//   3: double (slow on MRISC32, accurate)
//
#define DIV_METHOD 1

fixed_t FixedDiv (fixed_t a, fixed_t b)
{
    // Check for overflow/underflow.
    if ((abs (a) >> 14) >= abs (b))
        return (a ^ b) < 0 ? MININT : MAXINT;

#if DIV_METHOD == 1
    return (fixed_t) ((((long long)a) << 16) / ((long long)b));
#elif DIV_METHOD == 2
#ifdef __MRISC32_HARD_FLOAT__
    return (fixed_t) _mr32_ftoir ((float)a / (float)b, FRACBITS);
#else
    return (fixed_t) ((((float)a * (float)FRACUNIT)) / (float)b);
#endif
#elif DIV_METHOD == 3
    return (fixed_t) ((((double)a * (float)FRACUNIT) / (double)b));
#endif  // DIV_METHOD == 3
}
