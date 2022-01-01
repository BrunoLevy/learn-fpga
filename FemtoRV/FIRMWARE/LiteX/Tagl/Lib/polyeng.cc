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
 * polyeng.cc
 *
 */


#include "polyeng.h"
#include <string.h>

GVertexPool  PolygonEngine::_vpool;
GPolygon     PolygonEngine::_p1;
GPolygon     PolygonEngine::_p2;
Mug          PolygonEngine::_mug[PE_MAX_HEIGHT];

// virtual constructor stuff

int PolygonEngine::_entries = 0;
PolygonEngine_VC_Entry PolygonEngine::_entry[VC_ENTRIES];

void PolygonEngine::Register(const PolygonEngine_MakeFun make,
			     int bytes_per_pixel,
			     int R_mask, int G_mask, int B_mask)
{
  assert(_entries < VC_ENTRIES);

  _entry[_entries].make = make;
  _entry[_entries].bytes_per_pixel = bytes_per_pixel;
  _entry[_entries].R_mask = R_mask;
  _entry[_entries].G_mask = G_mask;
  _entry[_entries].B_mask = B_mask;

  char *tmp;

  if((tmp = getenv("GVERBOSE")) && (atoi(tmp) >=  MSG_INFO))
    {
	printf(
	    "[TAGL_VC] PolygonEngine::Register() called - %d entries\n", 
	    _entries+1
	);
      
	printf(
	    "[TAGL_VC] PEVC entry:: bytes per pixel = %d\n", 
	    _entry[_entries].bytes_per_pixel
	);

	printf("[TAGL_VC] PEVC entry:: R mask = ");
	printb(_entry[_entries].R_mask); printf("\n");

	printf("[TAGL_VC] PEVC entry:: G mask = ");
	printb(_entry[_entries].G_mask); printf("\n");

	printf("[TAGL_VC] PEVC entry:: B mask = ");
	printb(_entry[_entries].B_mask); printf("\n");
    }

  _entries++;
}

PolygonEngine* PolygonEngine::Make(GraphicPort *GP, int verb)
{
  int i;
  PolygonEngine *PE = NULL;

  char *tmp;
  if(verb == MSG_ENV)
    verb = (tmp = getenv("GVERBOSE")) ? atoi(tmp) : MSG_NONE;

  for(i=0; i<_entries; i++)
    {
      if((_entry[i].bytes_per_pixel == GP->BytesPerPixel()) &&  
	 (int(_entry[i].R_mask) == GP->RMask())         &&
         (int(_entry[i].G_mask) == GP->GMask())         &&
         (int(_entry[i].B_mask) == GP->BMask())         &&
	 (PE = _entry[i].make(GP,verb)))
	{
	  if(verb >= MSG_INFO)
	      printf("[TAGL_VC] PolygonEngine::Make() using entry %d\n",i);
	  return PE;
	}

      if(!_entry[i].bytes_per_pixel  &&  
	 !GP->BytesPerPixel()        &&
	 (PE = _entry[i].make(GP,verb)))
	{
	  if(verb >= MSG_INFO)
	    {
		printf("[TAGL_VC] PolygonEngine::Make() using entry %d\n",i);
		printf("[TAGL_VC] PolygonEngine::Make() using system graphics\n");
	    }
	  return PE;
	}

    }

  if(verb >= MSG_ERROR)
      printf("[TAGL_VC] PolygonEngine::Make() No suitable polygon engine found - unsucessful\n");

  return NULL;
}



PolygonEngine::PolygonEngine(GraphicPort *gp, int verb) : GraphicProcessor(gp)
{
  _proc_name = "unknown PolygonEngine";
  Verbose(verb);
}

PolygonEngine::~PolygonEngine(void)
{
}

// Sutherland-Hodgman Polygon clipping

void PolygonEngine::ClipPoly(void)

{
  int i,j;
  int flag, old_flag;
  GVertex *S, *P, *I;
  int clip_z  = Attributes().Get(GA_ZBUFFER) || Attributes().Get(PEA_ZCLIP);

  _vpool.Reset();

/* --------------- clip with x = _clip._x1 ---------------- */

  _p2.Reset();
  if(!_p1.Size())
    return;
  S = _p1[0];
  old_flag = S->x < _clip._x1;

  for(i=1; i<=_p1.Size(); i++)
    {
      j = i < _p1.Size() ? i : 0;
      P = _p1[j];
      flag = P->x < _clip._x1;

      if(flag ^ old_flag)
	{
	  I = _vpool.New();
	  I->flags.Set(VF_CLIP);
	  I->x = _clip._x1;
	  I->y = S->y + (_clip._x1 - S->x) * (P->y - S->y) / (P->x - S->x);

	  if(Attributes().Get(GA_GOURAUD))
	    {
	      if(Attributes().Get(GA_RGB))
		{
		  I->r = S->r + (_clip._x1 - S->x) * (P->r - S->r) / (P->x - S->x);
		  I->g = S->g + (_clip._x1 - S->x) * (P->g - S->g) / (P->x - S->x);
		  I->b = S->b + (_clip._x1 - S->x) * (P->b - S->b) / (P->x - S->x);
		}
	      else
		I->c = S->c + (_clip._x1 - S->x) * (P->c - S->c) / (P->x - S->x);
	    }

	  if(Attributes().Get(GA_TEXTURE))
	    {
	      I->X = S->X + (_clip._x1 - S->x) * (P->X - S->X) / (P->x - S->x);
	      I->Y = S->Y + (_clip._x1 - S->x) * (P->Y - S->Y) / (P->x - S->x);
	    }

	  if(clip_z)
	    {
	      I->z = S->z + (_clip._x1 - S->x) * (P->z - S->z) / (P->x - S->x);
	    }

	  if(Attributes().Get(GA_HCLIP))
	    {
	      I->w = S->w + (_clip._x1 - S->x) * (P->w - S->w) / (P->x - S->x);
	    }

          _p2.Push(I);
	}

      if(!flag)
	_p2.Push(P);

      S = P;
      old_flag = flag;
    }


/* --------------- clip with x = _clip._x2 ---------------- */

  _p1.Reset();
  if(!_p2.Size())
    return;
  S = _p2[0];
  old_flag = S->x > _clip._x2;


  for(i=1; i<=_p2.Size(); i++)
    {
      j = i < _p2.Size() ? i : 0;
      P = _p2[j];
      flag = P->x > _clip._x2;

      if(flag ^ old_flag)
	{
	  I = _vpool.New();
	  I->flags.Set(VF_CLIP);

	  I->x = _clip._x2;
	  I->y = P->y - (P->x - _clip._x2) * (P->y - S->y) / (P->x - S->x);

	  if(Attributes().Get(GA_GOURAUD))
	    {
	      if(Attributes().Get(GA_RGB))
		{
		  I->r = P->r - (P->x - _clip._x2) * (P->r - S->r) / (P->x - S->x);
		  I->g = P->g - (P->x - _clip._x2) * (P->g - S->g) / (P->x - S->x);
		  I->b = P->b - (P->x - _clip._x2) * (P->b - S->b) / (P->x - S->x);
		}
	      else
		I->c = P->c - (P->x - _clip._x2) * (P->c - S->c) / (P->x - S->x);
	    }

	  if(Attributes().Get(GA_TEXTURE))
	    {
	      I->X = P->X - (P->x - _clip._x2) * (P->X - S->X) / (P->x - S->x);
	      I->Y = P->Y - (P->x - _clip._x2) * (P->Y - S->Y) / (P->x - S->x);
	    }

	  if(clip_z)
	    {
	      I->z = P->z - (P->x - _clip._x2) * (P->z - S->z) / (P->x - S->x);
	    }

	  if(Attributes().Get(GA_HCLIP))
	    {
	      I->w = P->w - (P->x - _clip._x2) * (P->w - S->w) / (P->x - S->x);
	    }

	  _p1.Push(I);
	}

      if(!flag)
	_p1.Push(P);

      S = P;
      old_flag = flag;
    }

/* ---------------  clip with y = _clip._y1 ---------------- */

  _p2.Reset();
  if(!_p1.Size())
    return;
  S = _p1[0];
  old_flag = S->y < _clip._y1;


  for(i=1; i<=_p1.Size(); i++)
    {

      j = i < _p1.Size() ? i : 0;


      P = _p1[j];
      flag = P->y < _clip._y1;

      if(flag ^ old_flag)
	{
	
	  I = _vpool.New();
	  I->flags.Set(VF_CLIP);

	  I->y = _clip._y1;
	  I->x = S->x + (_clip._y1 - S->y) * (P->x - S->x) / (P->y - S->y);

	  if(Attributes().Get(GA_GOURAUD))
	    {
	      if(Attributes().Get(GA_RGB))
		{
		  I->r = S->r + (_clip._y1 - S->y) * (P->r - S->r) / (P->y - S->y);
		  I->g = S->g + (_clip._y1 - S->y) * (P->g - S->g) / (P->y - S->y);
		  I->b = S->b + (_clip._y1 - S->y) * (P->b - S->b) / (P->y - S->y);
		}
	      else
		I->c = S->c + (_clip._y1 - S->y) * (P->c - S->c) / (P->y - S->y);
	    }

	  if(Attributes().Get(GA_TEXTURE))
	    {
	      I->X = S->X + (_clip._y1 - S->y) * (P->X - S->X) / (P->y - S->y);
	      I->Y = S->Y + (_clip._y1 - S->y) * (P->Y - S->Y) / (P->y - S->y);
	    }

	  if(clip_z)
	    {
	      I->z = S->z + (_clip._y1 - S->y) * (P->z - S->z) / (P->y - S->y);
	    }

	  if(Attributes().Get(GA_HCLIP))
	    {
	      I->w = S->w + (_clip._y1 - S->y) * (P->w - S->w) / (P->y - S->y);
	    }

          _p2.Push(I);
	}

      if(!flag)
	_p2.Push(P);

      S = P;
      old_flag = flag;
    }

/* --------------- clip with y = _clip._y2 ---------------- */

  _p1.Reset();
  if(!_p2.Size())
    return;
  S = _p2[0];
  old_flag = S->y > _clip._y2;


  for(i=1; i<=_p2.Size(); i++)
    {
      j = i < _p2.Size() ? i : 0;
      P = _p2[j];
      flag = P->y > _clip._y2;

      if(flag ^ old_flag)
	{
	  I = _vpool.New();
	  I->flags.Set(VF_CLIP);

	  I->y = _clip._y2;
	  I->x = P->x - (P->y - _clip._y2) * (P->x - S->x) / (P->y - S->y);

	  if(Attributes().Get(GA_GOURAUD))
	    {
	      if(Attributes().Get(GA_RGB))
		{
		  I->r = P->r - (P->y - _clip._y2) * (P->r - S->r) / (P->y - S->y);
		  I->g = P->g - (P->y - _clip._y2) * (P->g - S->g) / (P->y - S->y);
		  I->b = P->b - (P->y - _clip._y2) * (P->b - S->b) / (P->y - S->y);
		}
	      else
		I->c = P->c - (P->y - _clip._y2) * (P->c - S->c) / (P->y - S->y);
	    }

	  if(Attributes().Get(GA_TEXTURE))
	    {
	      I->X = P->X - (P->y - _clip._y2) * (P->X - S->X) / (P->y - S->y);
	      I->Y = P->Y - (P->y - _clip._y2) * (P->Y - S->Y) / (P->y - S->y);
	    }

	  if(clip_z)
	    {
	      I->z = P->z - (P->y - _clip._y2) * (P->z - S->z) / (P->y - S->y);
	    }

	  if(Attributes().Get(GA_HCLIP))
	    {
	      I->w = P->w - (P->y - _clip._y2) * (P->w - S->w) / (P->y - S->y);
	    }

	  _p1.Push(I);
	}

      if(!flag)
	_p1.Push(P);

      S = P;
      old_flag = flag;
    }

  if(!(Attributes().Get(PEA_ZCLIP)))
    return;

/* ============= 3D clipping  ============== */

/* --------------- clip with z = _clip._z1 ---------------- */

  _p2.Reset();
  if(!_p1.Size())
    return;
  S = _p1[0];
  old_flag = S->z < _clip._z1;


  for(i=1; i<=_p1.Size(); i++)
    {

      j = i < _p1.Size() ? i : 0;


      P = _p1[j];
      flag = P->z < _clip._z1;

      if(flag ^ old_flag)
	{
	
	  I = _vpool.New();
	  I->flags.Set(VF_CLIP);

	  I->z = _clip._z1;
	  I->x = (ScrCoord)(S->x + (_clip._z1 - S->z) * (P->x - S->x) / (P->z - S->z));
	  I->y = (ScrCoord)(S->y + (_clip._z1 - S->z) * (P->y - S->y) / (P->z - S->z));

	  if(Attributes().Get(GA_GOURAUD))
	    {
	      if(Attributes().Get(GA_RGB))
		{
		  I->r = (ColorComponent)(S->r + (_clip._z1 - S->z) * (P->r - S->r)
					  / (P->z - S->z));
		  I->g = (ColorComponent)(S->g + (_clip._z1 - S->z) * (P->g - S->g) 
					  / (P->z - S->z));
		  I->b = (ColorComponent)(S->b + (_clip._z1 - S->z) * (P->b - S->b) 
					  / (P->z - S->z));
		}
	      else
		I->c = S->c + (_clip._z1 - S->z) * (P->c - S->c) / (P->z - S->z);
	    }

	  if(Attributes().Get(GA_TEXTURE))
	    {
	      I->X = (TexCoord)(S->X + (_clip._z1 - S->z) * (P->X - S->X) / (P->z - S->z));
	      I->Y = (TexCoord)(S->Y + (_clip._z1 - S->z) * (P->Y - S->Y) / (P->z - S->z));
	    }

	  if(Attributes().Get(GA_HCLIP))
	    {
	      I->w = S->w + (_clip._z1 - S->z) * (P->w - S->w) / (P->z - S->z);
	    }

          _p2.Push(I);
	}

      if(!flag)
	_p2.Push(P);

      S = P;
      old_flag = flag;
    }


/* --------------- clip with z = _clip._z2 ---------------- */

  _p1.Reset();
  if(!_p2.Size())
    return;
  S = _p2[0];
  old_flag = S->z > _clip._z2;


  for(i=1; i<=_p2.Size(); i++)
    {
      j = i < _p2.Size() ? i : 0;
      P = _p2[j];
      flag = P->z > _clip._z2;

      if(flag ^ old_flag)
	{
	  I = _vpool.New();
	  I->flags.Set(VF_CLIP);

	  I->z = _clip._z2;
	  I->x = (ScrCoord)(P->x - (P->z - _clip._z2) * (P->x - S->x) / (P->z - S->z));
	  I->y = (ScrCoord)(P->y - (P->z - _clip._z2) * (P->y - S->y) / (P->z - S->z));

	  if(Attributes().Get(GA_GOURAUD))
	    {
	      if(Attributes().Get(GA_RGB))
		{
		  I->r = (ColorComponent)(P->r - (P->z - _clip._z2) * (P->r - S->r) 
					  / (P->z - S->z));
		  I->g = (ColorComponent)(P->g - (P->z - _clip._z2) * (P->g - S->g) 
					  / (P->z - S->z));
		  I->b = (ColorComponent)(P->b - (P->z - _clip._z2) * (P->b - S->b) 
					  / (P->z - S->z));
		}
	      else
		I->c = P->c - (P->z - _clip._z2) * (P->c - S->c) / (P->z - S->z);
	    }

	  if(Attributes().Get(GA_TEXTURE))
	    {
	      I->X = (TexCoord)(P->X - (P->z - _clip._z2) * (P->X - S->X) / (P->z - S->z));
	      I->Y = (TexCoord)(P->Y - (P->z - _clip._z2) * (P->Y - S->Y) / (P->z - S->z));
	    }

	  if(Attributes().Get(GA_HCLIP))
	    {
	      I->w = P->w - (P->z - _clip._z2) * (P->w - S->w) / (P->z - S->z);
	    }

	  _p1.Push(I);
	}

      if(!flag)
	_p1.Push(P);

      S = P;
      old_flag = flag;
    }

  if(Attributes().Get(GA_HCLIP))
    for(i=0; i<_p1.Size(); i++)
      {
	if(!_p1[i]->flags.Get(VF_WDIV))
	  {
	    _p1[i]->flags.Set(VF_WDIV);
	    _p1[i]->x = (_p1[i]->x << GCOORD_SHIFT) / _p1[i]->w;
	    _p1[i]->y = (_p1[i]->y << GCOORD_SHIFT) / _p1[i]->w;
	    _p1[i]->z = (_p1[i]->z << GCOORD_SHIFT) / _p1[i]->w;
	  }
      }
}
