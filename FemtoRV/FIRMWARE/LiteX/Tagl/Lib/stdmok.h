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
 * std_mok.h
 *
 *
 */

#ifndef STD_MOK_H
#define STD_MOK_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iostream>

using namespace std;


#ifdef __STDC__
#define Mconcat(x,y) x##y
#define PRM(x) x
#else
#define Mconcat(x,y) x/**/y
#define PRM(x) ()
#endif

#ifndef MAX
#define MAX(x,y) ((x) > (y) ? (x) : (y))
#endif

#ifndef MIN
#define MIN(x,y) ((x) < (y) ? (x) : (y))
#endif

#define RANGE(x,m,M) ((x) < (m) ? (m) : ((x) > (M) ? (M) : (x)))

#define SGN(x)   ((x) ? ( (x) > 0 ? 1 : -1 ) : 0)
#define ABS(x)   ((x) > 0 ? (x) : -(x) )

#define BIG 32000

#define NEW(x)        ((x *)malloc(sizeof(x)))
#define NEWARRAY(x,n) ((x *)malloc(sizeof(x) * (n)))

#define Error(s) { fprintf(stderr,"error %d: ",errno); perror(s); exit(1); }

typedef double dbl;

#endif





