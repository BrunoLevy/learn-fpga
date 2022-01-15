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
//      Fixed point arithemtics, implementation.
//
//-----------------------------------------------------------------------------

#ifndef __M_FIXED__
#define __M_FIXED__

#ifdef __MRISC32__
#include <mr32intrin.h>
#endif

//
// Fixed point, 32bit as 16.16.
//
#define FRACBITS                16
#define FRACUNIT                (1<<FRACBITS)

typedef int fixed_t;

//
// FixedMul - Fixed point multiplication.
// We inline this function for better performance.
//

static inline fixed_t FixedMul (fixed_t a, fixed_t b)
{
#if defined(__MRISC32_PACKED_OPS__)
    // TODO(m): This produces different results than the generic long long
    // solution (or so it seems).
    fixed_t hi = _mr32_mulhi (a, b);
    fixed_t lo = ((unsigned)(a * b)) >> 16;
    return _mr32_pack (hi, lo);
#else
    return ((long long) a * (long long) b) >> FRACBITS;
#endif
}

//
// FixedDiv - Fixed point division.
//

fixed_t FixedDiv (fixed_t a, fixed_t b);

//
// INT_TO_FIXED - Convert an integer to fixed point.
//
#define INT_TO_FIXED(x) (fixed_t)(((unsigned)(fixed_t)(x)) << FRACBITS)

#endif  // __M_FIXED__
