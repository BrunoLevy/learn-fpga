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
 * gendraw.h
 * generic line drawing routine
 *
 *
 */

/*
 * types to be defined :
 *
 * o ScrCoord
 * o ZCoord
 * o ColorIndex
 * o ColorComponent
 * o TexCoord
 *
 * macros to be defined :
 *
 * o GENDRAW_C, RGB, A, Z, XY
 * o GENDRAW_NAME
 * o GENDRAW_DO_PIXEL
 * o GENDRAW_PIXEL
 * o GENDRAW_HEAD
 * o GENDRAW_SCAN
 *
 * ---------- C   -----------
 * 
 * o GENDRAW_C_SHIFT
 * o GENDRAW_C_MAX
 *
 * ---------- RGB -----------
 *
 * o GENDRAW_RGB_SHIFT
 * o GENDRAW_RGB_MAX
 * o GENDRAW_RGB_COMBINE 
 * o GENDRAW_R_SHIFT |
 * o GENDRAW_G_SHIFT | if GENDRAW_RGB_COMBINE
 * o GENDRAW_B_SHIFT |
 *
 * o GENDRAW_PRECISION_OVERRIDE
 *
 */

#ifndef MIN
#define MIN(x,y) (((x) < (y)) ? (x) : (y))
#endif

#ifndef MAX
#define MAX(x,y) (((x) > (y)) ? (x) : (y))
#endif

#ifndef SGN
#define SGN(x)   (((x) > (0)) ? 1 : ((x) ? -1 : 0))
#endif

void GENDRAW_NAME(GVertexAttributes *VA, GVertex *V1, GVertex *V2)

{
  GENDRAW_PIXEL *graph_ptr;
  int graph_line;
  int u;
   
#ifdef GENDRAW_RGB_COMBINE
  unsigned int cw;
#endif

#ifdef GENDRAW_Z
  ZCoord *z_ptr;
  int z_line;
#endif

#ifdef GENDRAW_HEAD
  GENDRAW_HEAD
#endif

  // geometric attributes (always used)
  ScrCoord y,y1,y2,dy,sy,ey;
  ScrCoord x,x1,x2,dx,sx,ex;

  // color attribute (colormap mode)       
#ifdef GENDRAW_C
  ColorCode c,c1,c2,dc,sc,ec;
#endif

  // color attribute (rgb mode)            
#ifdef GENDRAW_RGB
  ColorComponent r,r1,r2,dr,sr,er;
  ColorComponent g,g1,g2,dg,sg,eg;
  ColorComponent b,b1,b2,db,sb,eb;
#endif

// alpha attribute                    
#ifdef GENDRAW_A
  ColorComponent a,a1,a2,da,sa,ea;
#endif

// Z attribute (ZBuffer mode)             
#ifdef GENDRAW_Z
  SZCoord        z,z1,z2,dz,sz,ez;
#endif

// Texel attribute (Texture mapping mode)
#ifdef GENDRAW_XY
  TexCoord       X,X1,X2,dX,sX,eX;
  TexCoord       Y,Y1,Y2,dY,sY,eY;
#endif


  y1 = V1->y;
  y2 = V2->y;
  dy = y2 - y1;
  sy = SGN(dy);
  dy *= sy;
  y  = y1;



  x1 = V1->x;
  x2 = V2->x;
  dx = x2 - x1;
  sx = SGN(dx);
  dx *= sx;
  


#ifdef GENDRAW_C

  c1 = MIN(V1->c,GENDRAW_C_MAX) >> GENDRAW_C_SHIFT;
  c2 = MIN(V2->c,GENDRAW_C_MAX) >> GENDRAW_C_SHIFT;
  dc = c2 - c1;
  sc = SGN(dc);
  dc *= sc;
  c  = c1;

#endif

#ifdef GENDRAW_RGB

  r1 = V1->r;
  r2 = V2->r;
  
  g1 = V1->g;
  g2 = V2->g;
  
  b1 = V1->b;
  b2 = V2->b;

#ifndef  GENDRAW_PRECISION_OVERRIDE

  r1 = MIN(r1,GENDRAW_RGB_MAX) >> GENDRAW_RGB_SHIFT;
  r2 = MIN(r2,GENDRAW_RGB_MAX) >> GENDRAW_RGB_SHIFT;
  
  g1 = MIN(g1,GENDRAW_RGB_MAX) >> GENDRAW_RGB_SHIFT;
  g2 = MIN(g2,GENDRAW_RGB_MAX) >> GENDRAW_RGB_SHIFT;
  
  b1 = MIN(b1,GENDRAW_RGB_MAX) >> GENDRAW_RGB_SHIFT;
  b2 = MIN(b2,GENDRAW_RGB_MAX) >> GENDRAW_RGB_SHIFT;

#else

  r1 = MIN(r1,GENDRAW_RGB_MAX) << GENDRAW_RGB_SHIFT;
  r2 = MIN(r2,GENDRAW_RGB_MAX) << GENDRAW_RGB_SHIFT;
  
  g1 = MIN(g1,GENDRAW_RGB_MAX) << GENDRAW_RGB_SHIFT;
  g2 = MIN(g2,GENDRAW_RGB_MAX) << GENDRAW_RGB_SHIFT;
  
  b1 = MIN(b1,GENDRAW_RGB_MAX) << GENDRAW_RGB_SHIFT;
  b2 = MIN(b2,GENDRAW_RGB_MAX) << GENDRAW_RGB_SHIFT;

#endif

  dr = r2 - r1;
  sr = SGN(dr);
  dr *= sr;
  r  = r1;

  dg = g2 - g1;
  sg = SGN(dg);
  dg *= sg;
  g  = g1;

  db = b2 - b1;
  sb = SGN(db);
  db *= sb;
  b  = b1;

#endif

#ifdef GENDRAW_A

  a1 = V1->a;
  a2 = V2->a;
  da = a2 - a1;
  sa = SGN(da);
  da *= sa;
  a  = a1;

#endif

#ifdef GENDRAW_Z

  z1 = V1->z;
  z2 = V2->z;
  dz = z2 - z1;
  sz = SGN(dz);
  dz *= sz;
  z  = z1;

#endif

#ifdef GENDRAW_XY

  X1 = V1->X;
  X2 = V2->X;
  dX = X2 - X1;
  sX = SGN(dX);
  dX *= sX;
  X  = X1;

  Y1 = V1->Y;
  Y2 = V2->Y;
  dY = Y2 - Y1;
  sY = SGN(dY);
  dY *= sY;
  Y  = Y1;

#endif


  graph_ptr  = (GENDRAW_PIXEL *)(_graph_mem + y1 * _bytes_per_line + 
				 x1 * sizeof(GENDRAW_PIXEL));
  graph_line = sy * _bytes_per_line;

#ifdef GENDRAW_Z
  z_ptr  = _z_mem + y1 * _width + x1;
  z_line = sy * _width; 
#endif

  x = x1;
  y = y1;

  if(dy > dx)
    {
        ex = (dx << 1) - dy;
#ifdef GENDRAW_C
	ec = (dc << 1) - dy;
#endif
#ifdef GENDRAW_RGB
	er = (dr << 1) - dy;
	eg = (dg << 1) - dy;
	eb = (db << 1) - dy;
#endif
#ifdef GENDRAW_A
	ea = (da << 1) - dy;
#endif
#ifdef GENDRAW_Z
	ez = (dz << 1) - dy;
#endif
#ifdef GENDRAW_XY
	eX = (dX << 1) - dy;
	eY = (dY << 1) - dy;
#endif

	for(u=0; u<dy; u++)
	  {
	    GENDRAW_DO_PIXEL;
	    y += sy;
	    graph_ptr = (GENDRAW_PIXEL *)((char *)graph_ptr + graph_line);
#ifdef GENDRAW_Z
	    z_ptr     += z_line;
#endif
	    
	    while(ex >= 0)
	      {
		GENDRAW_DO_PIXEL;
		x += sx;
		graph_ptr += sx;
#ifdef GENDRAW_Z
		z_ptr += sx;
#endif
		ex -= dy << 1;
	      }
	    
	    ex += dx << 1;
	    

#ifdef GENDRAW_C

	    while(ec >= 0)
	      {
		c  += sc;
		ec -= dy << 1;
	      }
	    
	    ec += dc << 1;
	    
#endif

#ifdef GENDRAW_RGB

	    while(er >= 0)
	      {
		r += sr;
		er -= dy << 1;
	      }
	    
	    er += dr << 1;
	    
	    while(eg >= 0)
	      {
		g += sg;
		eg -= dy << 1;
	      }
	    
	    eg += dg << 1;
	    
	    while(eb >= 0)
	      {
		b += sb;
		eb -= dy << 1;
	      }
	    
	    eb += db << 1;

#endif

#ifdef GENDRAW_A

	    while(ea >= 0)
	      {
		a += sa;
		ea -= dy << 1;
	      }
	    
	    ea += da << 1;

#endif

#ifdef GENDRAW_Z

	    while(ez >= 0)
	      {
		z += sz;
		ez -= dy << 1;
	      }
	    
	    ez += dz << 1;

#endif

#ifdef GENDRAW_XY

	    while(eX >= 0)
	      {
		X += sX;
		eX -= dy << 1;
	      }
	    
	    eX += dX << 1;
	    
	    while(eY >= 0)
	      {
		Y += sY;
		eY -= dy << 1;
	      }

	    eY += dY << 1;

#endif

	  }

    }
  else
    {
        ey = (dy << 1) - dx;
#ifdef GENDRAW_C
	ec = (dc << 1) - dx;
#endif
#ifdef GENDRAW_RGB
	er = (dr << 1) - dx;
	eg = (dg << 1) - dx;
	eb = (db << 1) - dx;
#endif
#ifdef GENDRAW_A
	ea = (da << 1) - dx;
#endif
#ifdef GENDRAW_Z
	ez = (dz << 1) - dx;
#endif
#ifdef GENDRAW_XY
	eX = (dX << 1) - dx;
	eY = (dY << 1) - dx;
#endif
	
	for(u=0; u<dx; u++)
	  {
	    GENDRAW_DO_PIXEL
	    x += sx;
	    graph_ptr += sx;
#ifdef GENDRAW_Z
	    z_ptr     += sx;
#endif
	    
	    while(ey >= 0)
	      {
		GENDRAW_DO_PIXEL
		y += sy;
		graph_ptr = (GENDRAW_PIXEL *)((char *)graph_ptr + graph_line);
#ifdef GENDRAW_Z
		z_ptr     += z_line;
#endif
		ey -= dx << 1;
	      }
	    
	    ey += dy << 1;
	    

#ifdef GENDRAW_C

	    while(ec >= 0)
	      {
		c  += sc;
		ec -= dx << 1;
	      }
	    
	    ec += dc << 1;
	    
#endif

#ifdef GENDRAW_RGB

	    while(er >= 0)
	      {
		r += sr;
		er -= dx << 1;
	      }
	    
	    er += dr << 1;
	    
	    while(eg >= 0)
	      {
		g += sg;
		eg -= dx << 1;
	      }
	    
	    eg += dg << 1;
	    
	    while(eb >= 0)
	      {
		b += sb;
		eb -= dx << 1;
	      }
	    
	    eb += db << 1;

#endif

#ifdef GENDRAW_A

	    while(ea >= 0)
	      {
		a += sa;
		ea -= dx << 1;
	      }
	    
	    ea += da << 1;

#endif

#ifdef GENDRAW_Z

	    while(ez >= 0)
	      {
		z += sz;
		ez -= dx << 1;
	      }
	    
	    ez += dz << 1;

#endif

#ifdef GENDRAW_XY

	    while(eX >= 0)
	      {
		X += sX;
		eX -= dx << 1;
	      }
	    
	    eX += dX << 1;
	    
	    while(eY >= 0)
	      {
		Y += sY;
		eY -= dx << 1;
	      }

	    eY += dY << 1;

#endif
	  }
      }
}

/*
 *
 * This file may be included several times in the same 
 * module.
 *
 */

#ifdef GENDRAW_C
#undef GENDRAW_C
#endif

#ifdef GENDRAW_C_SHIFT
#undef GENDRAW_C_SHIFT
#endif

#ifdef GENDRAW_C_MAX
#undef GENDRAW_C_MAX
#endif

#ifdef GENDRAW_RGB
#undef GENDRAW_RGB
#endif

#ifdef GENDRAW_RGB_SHIFT
#undef GENDRAW_RGB_SHIFT
#endif

#ifdef GENDRAW_RGB_MAX
#undef GENDRAW_RGB_MAX
#endif

#ifdef GENDRAW_RGB_COMBINE
#undef GENDRAW_RGB_COMBINE
#endif

#ifdef GENDRAW_R_SHIFT
#undef GENDRAW_R_SHIFT
#endif

#ifdef GENDRAW_G_SHIFT
#undef GENDRAW_G_SHIFT
#endif

#ifdef GENDRAW_B_SHIFT
#undef GENDRAW_B_SHIFT
#endif

#ifdef GENDRAW_A
#undef GENDRAW_A
#endif

#ifdef GENDRAW_Z
#undef GENDRAW_Z
#endif

#ifdef GENDRAW_XY
#undef GENDRAW_XY
#endif

#undef GENDRAW_NAME
#undef GENDRAW_DO_PIXEL
#undef GENDRAW_PIXEL

#ifdef GENDRAW_HEAD
#undef GENDRAW_HEAD
#endif

#ifdef GENDRAW_SCAN
#undef GENDRAW_SCAN
#endif

#ifdef GENDRAW_PRECISION_OVERRIDE
#undef GENDRAW_PRECISION_OVERRIDE
#endif
