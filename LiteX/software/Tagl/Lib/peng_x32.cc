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

// 32bpp polygon engine
// unused byte is most significant

#include "machine.h"

typedef uint32 PixelValue;

#define GENPE_CLASS PolygonEngine_x32
#define GENPE_DLD   init_peng_x32
#define GENPE_BYTES_PER_PIXEL 4
#define GENPE_R_SHIFT 16
#define GENPE_G_SHIFT 8
#define GENPE_B_SHIFT 0
#define GENPE_RGB_SHIFT 0
#define GENPE_RGB_MASK  255

#include "genpeng.h"

