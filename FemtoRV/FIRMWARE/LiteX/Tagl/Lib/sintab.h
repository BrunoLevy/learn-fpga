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
 * sinus.h
 *
 */


#ifndef SINUS_H
#define SINUS_H

#define SIN_SHIFT 15
#define SIN_MASK  255

#include "machine.h"

extern uint32 sintab[];
extern uint32 costab[];

typedef int Angle;

#define SIN0(x) (sintab[(x) & SIN_MASK])
#define SIN(x)  ((int32)((x) >= 0 ? SIN0(x) : -SIN0(-x)))

#define COS0(x) (costab[(x) & SIN_MASK])
#define COS(x)  ((int32)((x) >= 0 ? COS0(x) :  COS0(-x)))


inline int Sin(Angle x) { return SIN(x); }
inline int Cos(Angle x) { return COS(x); }


/*
#define SIN0(x) (sintab[x])
#define SIN1(x) ((x) & 256 ?  SIN0(511-(x)) : SIN0(x))
#define SIN2(x) ((x) & 512 ? -SIN1((x)-512) : SIN1(x))
#define SIN3(x) SIN2((x) & 1023)
#define SIN(x) ((x)>0 ? SIN3(x) : -SIN3(-x))

#define COS(x) SIN(x + 256)
*/

#endif
