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
 * LinG.h
 * Portable framebuffer interface
 *
 */

#ifndef LING_H
#define LING_H

#ifndef PRM
#ifdef __STDC__
#define PRM(x) x
#else
#define PRM(x) ()
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef unsigned char ling_pixel;
typedef unsigned char ling_colorcomponent;
typedef int           ling_coord;
typedef int           ling_key;
typedef int           ling_mousebuttons;
typedef unsigned long ling_modemask;


#define LGK_Return  -1
#define LGK_Escape  -2
#define LGK_Left    -3
#define LGK_Right   -4
#define LGK_Up      -5
#define LGK_Down    -6

#define LGM_Left     1
#define LGM_Middle   2
#define LGM_Right    4

#define LGF_Scale       1
#define LGF_DirectPixel 2

int           LinG_OpenScreen  PRM((ling_coord width, ling_coord height, 
                                    ling_modemask mode));
void          LinG_CloseScreen PRM((void));
ling_modemask LinG_GetMode     PRM((void));
ling_pixel   *LinG_GraphMem    PRM((void));
ling_pixel   *LinG_Colormap    PRM((void));
void          LinG_SwapBuffers PRM((void));
void          LinG_SetRGBColor PRM((ling_pixel idx, 
		 		    ling_colorcomponent r, 
				    ling_colorcomponent g, 
				    ling_colorcomponent b));



ling_key          LinG_GetKey   PRM((void));
ling_mousebuttons LinG_GetMouse PRM((ling_coord *x, ling_coord *y));

#ifdef __cplusplus
}
#endif

#endif

