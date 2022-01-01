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
 * genfill.h
 * generic convex polygon fill routine
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
 * o GENFILL_C, RGB, A, Z, XY
 * o GENFILL_NAME
 * o GENFILL_DO_PIXEL
 * o GENFILL_PIXEL
 * o GENFILL_TEXEL
 * o GENFILL_HEAD
 * o GENFILL_SCAN
 *
 * ---------- C   -----------
 * 
 * o GENFILL_C_SHIFT
 * o GENFILL_C_MAX
 *
 * ---------- RGB -----------
 *
 * o GENFILL_RGB_SHIFT
 * o GENFILL_RGB_MAX
 * o GENFILL_RGB_COMBINE 
 * o GENFILL_R_SHIFT |
 * o GENFILL_G_SHIFT | if GENFILL_RGB_COMBINE
 * o GENFILL_B_SHIFT |
 *
 * o GENFILL_PRECISION_OVERRIDE
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

void GENFILL_NAME(GVertexAttributes *VA)

{
  ScrCoord miny = 1000, maxy = -1;
  int i,j,u;
  GENFILL_PIXEL *graph_ptr, *graph_ptr0;
  int clock_wise = 0;
   
#ifdef GENFILL_RGB_COMBINE
  unsigned int cw;
#endif

#ifdef GENFILL_Z
  ZCoord *z_ptr, *z_ptr0;
#endif

#ifdef GENFILL_HEAD
  GENFILL_HEAD
#endif

  // geometric attributes (always used)
  ScrCoord y,y1,y2,dy,sy;
  ScrCoord x,x1,x2,dx,sx,ex;

  // color attribute (colormap mode)       
#ifdef GENFILL_C
  ColorCode c,c1,c2,dc,sc,ec;
#endif

  // color attribute (rgb mode)            
#ifdef GENFILL_RGB
  ColorComponent r,r1,r2,dr,sr,er;
  ColorComponent g,g1,g2,dg,sg,eg;
  ColorComponent b,b1,b2,db,sb,eb;
#endif

// alpha attribute                    
#ifdef GENFILL_A
  ColorComponent a,a1,a2,da,sa,ea;
#endif

// Z attribute (ZBuffer mode)             
#ifdef GENFILL_Z
  SZCoord        z,z1,z2,dz,sz,ez;
#endif

// Texel attribute (Texture mapping mode)
#ifdef GENFILL_XY
  TexCoord       X,X1,X2,dX,sX,eX;
  TexCoord       Y,Y1,Y2,dY,sY,eY;
  GENFILL_TEXEL* tex_ptr; 
#endif


  if(_p1.Size() < 2)
    return;

   /* Get clockwise, min and max y */

  for(i=0; i<_p1.Size(); i++)
     {
       int j = i+1;
       if(j == _p1.Size())
	 j = 0;

       int k = j+1;
       if(k == _p1.Size())
	 k = 0;

       int dx1 = _p1[i]->x - _p1[j]->x;
       int dy1 = _p1[i]->y - _p1[j]->y;
       int dx2 = _p1[k]->x - _p1[j]->x;
       int dy2 = _p1[k]->y - _p1[j]->y;
	
       clock_wise += dx1 * dy2 - dx2 * dy1;

       miny = MIN(miny,_p1[i]->y);
       maxy = MAX(maxy,_p1[i]->y);

/*	
#ifdef GENFILL_XY
       _p1[i]->X &= _tex_mask;
       _p1[i]->Y &= _tex_mask;
#endif
 */ 
     }

  clock_wise = (clock_wise > 0);

  if(miny == maxy)
    return;
  
  for(i=0; i<_p1.Size(); i++)
    {
      j = i+1;

      if(j==_p1.Size())
	j = 0;


      if(_p1[i]->y == _p1[j]->y)
	continue;
      
      
      y1 = _p1[i]->y;
      y2 = _p1[j]->y;
      dy = y2 - y1;
      sy = SGN(dy);
      dy *= sy;
      y  = y1;


      x1 = _p1[i]->x;
      x2 = _p1[j]->x;
      dx = x2 - x1;
      sx = SGN(dx);
      dx *= sx;
      ex = (dx << 1) - dy;
      x  = x1;

#ifdef GENFILL_C

      c1 = MIN(_p1[i]->c,GENFILL_C_MAX) >> GENFILL_C_SHIFT;
      c2 = MIN(_p1[j]->c,GENFILL_C_MAX) >> GENFILL_C_SHIFT;
      dc = c2 - c1;
      sc = SGN(dc);
      dc *= sc;
      ec = (dc << 1) - dy;
      c  = c1;

#endif

#ifdef GENFILL_RGB

      r1 = _p1[i]->r;
      r2 = _p1[j]->r;

      g1 = _p1[i]->g;
      g2 = _p1[j]->g;

      b1 = _p1[i]->b;
      b2 = _p1[j]->b;

#ifndef  GENFILL_PRECISION_OVERRIDE

      r1 = MIN(r1,GENFILL_RGB_MAX) >> GENFILL_RGB_SHIFT;
      r2 = MIN(r2,GENFILL_RGB_MAX) >> GENFILL_RGB_SHIFT;

      g1 = MIN(g1,GENFILL_RGB_MAX) >> GENFILL_RGB_SHIFT;
      g2 = MIN(g2,GENFILL_RGB_MAX) >> GENFILL_RGB_SHIFT;

      b1 = MIN(b1,GENFILL_RGB_MAX) >> GENFILL_RGB_SHIFT;
      b2 = MIN(b2,GENFILL_RGB_MAX) >> GENFILL_RGB_SHIFT;

#else

      r1 = MIN(r1,GENFILL_RGB_MAX) << GENFILL_RGB_SHIFT;
      r2 = MIN(r2,GENFILL_RGB_MAX) << GENFILL_RGB_SHIFT;

      g1 = MIN(g1,GENFILL_RGB_MAX) << GENFILL_RGB_SHIFT;
      g2 = MIN(g2,GENFILL_RGB_MAX) << GENFILL_RGB_SHIFT;

      b1 = MIN(b1,GENFILL_RGB_MAX) << GENFILL_RGB_SHIFT;
      b2 = MIN(b2,GENFILL_RGB_MAX) << GENFILL_RGB_SHIFT;

#endif

      dr = r2 - r1;
      sr = SGN(dr);
      dr *= sr;
      er = (dr << 1) - dy;
      r  = r1;

      dg = g2 - g1;
      sg = SGN(dg);
      dg *= sg;
      eg = (dg << 1) - dy;
      g  = g1;

      db = b2 - b1;
      sb = SGN(db);
      db *= sb;
      eb = (db << 1) - dy;
      b  = b1;

#endif

#ifdef GENFILL_A

      a1 = _p1[i]->a;
      a2 = _p1[j]->a;
      da = a2 - a1;
      sa = SGN(da);
      da *= sa;
      ea = (da << 1) - dy;
      a  = a1;

#endif

#ifdef GENFILL_Z

      z1 = _p1[i]->z;
      z2 = _p1[j]->z;
      dz = z2 - z1;
      sz = SGN(dz);
      dz *= sz;
      ez = (dz << 1) - dy;
      z  = z1;

#endif

#ifdef GENFILL_XY

      X1 = _p1[i]->X;
      X2 = _p1[j]->X;
      dX = X2 - X1;
      sX = SGN(dX);
      dX *= sX;
      eX = (dX << 1) - dy;
      X  = X1;

      Y1 = _p1[i]->Y;
      Y2 = _p1[j]->Y;
      dY = Y2 - Y1;
      sY = SGN(dY);
      dY *= sY;
      eY = (dY << 1) - dy;
      Y  = Y1;

#endif

      if(clock_wise ^ (y2 > y1))
	 {
	    /* Right pixel */

	    for(u=0; u <= dy; u++)
	      {
		 _mug[y]._right.x = x;
#ifdef GENFILL_C
		 _mug[y]._right.c = c;
#endif
#ifdef GENFILL_RGB
		  _mug[y]._right.r = r;
		  _mug[y]._right.g = g;
		  _mug[y]._right.b = b;
#endif
#ifdef GENFILL_A
		  _mug[y]._right.a = a;
#endif
#ifdef GENFILL_Z
		  _mug[y]._right.z = z;
#endif
#ifdef GENFILL_XY
		  _mug[y]._right.X = X;
		  _mug[y]._right.Y = Y;
#endif

		 y += sy;

		 while(ex >= 0)
		   {
		      x += sx;
		      ex -= dy << 1;
		   }

		 ex += dx << 1;


#ifdef GENFILL_C

		 while(ec >= 0)
		   {
		      c  += sc;
		      ec -= dy << 1;
		   }

		 ec += dc << 1;

#endif

#ifdef GENFILL_RGB

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

#ifdef GENFILL_A

		 while(ea >= 0)
		   {
		      a += sa;
		      ea -= dy << 1;
		   }

		 ea += da << 1;

#endif

#ifdef GENFILL_Z

		 while(ez >= 0)
		   {
		      z += sz;
		      ez -= dy << 1;
		   }

		 ez += dz << 1;

#endif

#ifdef GENFILL_XY

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
	    /* Left pixel */
	    
	    for(u=0; u <= dy; u++)
	      {
		 _mug[y]._left.x = x;
#ifdef GENFILL_C
		 _mug[y]._left.c = c;
#endif
#ifdef GENFILL_RGB
		 _mug[y]._left.r = r;
		 _mug[y]._left.g = g;
		 _mug[y]._left.b = b;
#endif
#ifdef GENFILL_A
		 _mug[y]._left.a = a;
#endif
#ifdef GENFILL_Z
		 _mug[y]._left.z = z;
#endif
#ifdef GENFILL_XY
		 _mug[y]._left.X = X;
		 _mug[y]._left.Y = Y;
#endif

		 y += sy;

		 while(ex >= 0)
		   {
		      x += sx;
		      ex -= dy << 1;
		   }

		 ex += dx << 1;


#ifdef GENFILL_C

		 while(ec >= 0)
		   {
		      c  += sc;
		      ec -= dy << 1;
		   }

		 ec += dc << 1;

#endif

#ifdef GENFILL_RGB

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

#ifdef GENFILL_A

		 while(ea >= 0)
		   {
		      a += sa;
		      ea -= dy << 1;
		   }

		 ea += da << 1;

#endif

#ifdef GENFILL_Z

		 while(ez >= 0)
		   {
		      z += sz;
		      ez -= dy << 1;
		   }

		 ez += dz << 1;

#endif

#ifdef GENFILL_XY

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
       

    }

  graph_ptr0 = (GENFILL_PIXEL *)(_graph_mem + miny * _bytes_per_line);
  
#ifdef GENFILL_Z
  z_ptr0 = _z_mem + miny * _width;
#endif

  for(y=miny; y<=maxy; y++)
    {
      x1 = _mug[y]._left.x;
      x2 = _mug[y]._right.x;
      dx = x2 - x1 + 1;
      x  = x1;

#ifdef GENFILL_SCAN

      graph_ptr = graph_ptr0 + x1;

GENFILL_SCAN

#else
#ifdef GENFILL_C
      c1 = _mug[y]._left.c;
      c2 = _mug[y]._right.c;
      dc = c2 - c1;
      sc = SGN(dc);
      dc *= sc;
      ec = (dc << 1) - dx;
      c  = c1;
#endif

#ifdef GENFILL_RGB
      r1 = _mug[y]._left.r;
      r2 = _mug[y]._right.r;
      dr = r2 - r1;
      sr = SGN(dr);
      dr *= sr;
      er = (dr << 1) - dx;
      r  = r1;

      g1 = _mug[y]._left.g;
      g2 = _mug[y]._right.g;
      dg = g2 - g1;
      sg = SGN(dg);
      dg *= sg;
      eg = (dg << 1) - dx;
      g  = g1;

      b1 = _mug[y]._left.b;
      b2 = _mug[y]._right.b;
      db = b2 - b1;
      sb = SGN(db);
      db *= sb;
      eb = (db << 1) - dx;
      b  = b1;

#ifdef GENFILL_RGB_COMBINE
      sr *= GENFILL_R_SHIFT;
      sg *= GENFILL_G_SHIFT;
      sb *= GENFILL_B_SHIFT;

      cw = (r << GENFILL_R_SHIFT) | 
	   (g << GENFILL_G_SHIFT) | 
	   (b << GENFILL_B_SHIFT);
#endif

#endif      

#ifdef GENFILL_A
      a1 = _mug[y]._left.a;
      a2 = _mug[y]._right.a;
      da = a2 - a1;
      sa = SGN(da);
      da *= sa;
      ea = (da << 1) - dx;
      a  = a1;
#endif

#ifdef GENFILL_Z
      z1 = _mug[y]._left.z;
      z2 = _mug[y]._right.z;
      dz = z2 - z1;
      sz = SGN(dz);
      dz *= sz;
      ez = (dz << 1) - dx;
      z  = z1;
#endif

#ifdef GENFILL_XY
      X1 = _mug[y]._left.X;
      X2 = _mug[y]._right.X;
      dX = X2 - X1;
      sX = SGN(dX);
      dX *= sX;
      eX = (dX << 1) - dx;
      X  = X1; 

      Y1 = _mug[y]._left.Y;
      Y2 = _mug[y]._right.Y;
      dY = Y2 - Y1;
      sY = SGN(dY);
      dY *= sY;
      eY = (dY << 1) - dx;
      Y  = Y1; 
/*      tex_ptr = (GENFILL_TEXEL *)_tex_mem + (Y1 << _tex_shift) + X1; */
#endif

      graph_ptr = graph_ptr0 + x1;

#ifdef GENFILL_Z
      z_ptr     = z_ptr0 + x1;
#endif


      for(x=x1; x <= x2; x++)
	{

#ifdef GENFILL_XY
	   tex_ptr = (GENFILL_TEXEL *)_tex_mem + (( Y & _tex_mask) << _tex_shift) + ( X & _tex_mask );
#endif	   
	   
	  GENFILL_DO_PIXEL

#ifdef GENFILL_C

	  while(ec >= 0)
	    {
	      c  += sc;
	      ec -= dx << 1;
	    }

	  ec += dc << 1;

#endif

#ifdef GENFILL_RGB

#ifdef GENFILL_RGB_COMBINE

	  while(er >= 0)
	    {
	      cw += sr;
	      er -= dx << 1;
	    }

	  er += dr << 1;

	  while(eg >= 0)
	    {
	      cw += sg;
	      eg -= dx << 1;
	    }

	  eg += dg << 1;

	  while(eb >= 0)
	    {
	      cw += sb;
	      eb -= dx << 1;
	    }

	  eb += db << 1;
#else
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
#endif

#ifdef GENFILL_A

	  while(ea >= 0)
	    {
	      a += sa;
	      ea -= dx << 1;
	    }

	  ea += da << 1;

#endif

#ifdef GENFILL_Z

	  while(ez >= 0)
	    {
	      z += sz;
	      ez -= dx << 1;
	    }

	  ez += dz << 1;

#endif

#ifdef GENFILL_XY

	  while(eX >= 0)
	    {
	      X += sX; 
/*	      tex_ptr += sX; */
	      eX -= dx << 1;
	    }

	  eX += dX << 1;

	  while(eY >= 0)
	    {
	      Y += sY; 
/*	      tex_ptr += (sY << _tex_shift); */
	      eY -= dx << 1;
	    }

	  eY += dY << 1;

#endif

	  graph_ptr++;
#ifdef GENFILL_Z
	  z_ptr++;
#endif

	}
#endif
      graph_ptr0 = (GENFILL_PIXEL *)(((char *)graph_ptr0) + _bytes_per_line);
#ifdef GENFILL_Z
      z_ptr0     += _width;
#endif
    }

}


/*
 *
 * This file may be included several times in the same 
 * module.
 *
 */

#ifdef GENFILL_C
#undef GENFILL_C
#endif

#ifdef GENFILL_C_SHIFT
#undef GENFILL_C_SHIFT
#endif

#ifdef GENFILL_C_MAX
#undef GENFILL_C_MAX
#endif

#ifdef GENFILL_RGB
#undef GENFILL_RGB
#endif

#ifdef GENFILL_RGB_SHIFT
#undef GENFILL_RGB_SHIFT
#endif

#ifdef GENFILL_RGB_MAX
#undef GENFILL_RGB_MAX
#endif

#ifdef GENFILL_RGB_COMBINE
#undef GENFILL_RGB_COMBINE
#endif

#ifdef GENFILL_R_SHIFT
#undef GENFILL_R_SHIFT
#endif

#ifdef GENFILL_G_SHIFT
#undef GENFILL_G_SHIFT
#endif

#ifdef GENFILL_B_SHIFT
#undef GENFILL_B_SHIFT
#endif

#ifdef GENFILL_A
#undef GENFILL_A
#endif

#ifdef GENFILL_Z
#undef GENFILL_Z
#endif

#ifdef GENFILL_XY
#undef GENFILL_XY
#endif

#undef GENFILL_NAME
#undef GENFILL_DO_PIXEL
#undef GENFILL_PIXEL

#ifdef GENFILL_TEXEL
#undef GENFILL_TEXEL
#endif

#ifdef GENFILL_HEAD
#undef GENFILL_HEAD
#endif

#ifdef GENFILL_SCAN
#undef GENFILL_SCAN
#endif

#ifdef GENFILL_PRECISION_OVERRIDE
#undef GENFILL_PRECISION_OVERRIDE
#endif
