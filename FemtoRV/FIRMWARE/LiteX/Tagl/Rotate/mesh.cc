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
 * mesh.C
 *
 */


#include "mesh.h"
#include <string.h>
#include "texture.h"

static const int verbose = 1;

// I do not use MVector::RotX cause it would call Sin() and Cos() 
// for each vertex ...

Mesh::Mesh(void)
{
  _vertex  = NULL;
  _face    = NULL;
  _nvertex = 0;
  _nface   = 0;
  _resources  = MR_NONE;
  _error_code = ME_NONE;
  _flags      = MF_NONE;
}


Mesh::~Mesh(void)
{
  if(_resources.Get(MR_FACES))
    delete[] _face;
  if(_resources.Get(MR_VERTICES))
    delete[] _vertex;
}



void Mesh::RotX(Angle r)
{
  int i;
  long s = Sin(r),c = Cos(r);
  long t1, t2;


  for(i=0; i < _nvertex; i++)
    {
      t1 = _vertex[i].y;
      t2 = _vertex[i].z;
      _vertex[i].y = (int)(( c * t1 + s * t2) >> SIN_SHIFT);
      _vertex[i].z = (int)((-s * t1 + c * t2) >> SIN_SHIFT);

      if(_resources.Get(MR_SMOOTH))
	{
	  t1 = _vertex[i].N.y;
	  t2 = _vertex[i].N.z;
	  _vertex[i].N.y = (int)(( c * t1 + s * t2) >> SIN_SHIFT);
	  _vertex[i].N.z = (int)((-s * t1 + c * t2) >> SIN_SHIFT);
	}
    }

  for(i=0; i < _nface; i++)
    {
      t1 = _face[i].N.y;
      t2 = _face[i].N.z;
      _face[i].N.y = (int)(( c * t1 + s * t2) >> SIN_SHIFT);
      _face[i].N.z = (int)((-s * t1 + c * t2) >> SIN_SHIFT);
    }
}


void Mesh::RotY(Angle r)
{
  int i;
  long s = Sin(r),c = Cos(r);
  long t1,t2;

  for(i=0; i < _nvertex; i++)
    {
      t1 = _vertex[i].x;
      t2 = _vertex[i].z;
      _vertex[i].x = (int)(( c * t1 + s * t2) >> SIN_SHIFT);
      _vertex[i].z = (int)((-s * t1 + c * t2) >> SIN_SHIFT);

      if(_resources.Get(MR_SMOOTH))
	{
	  t1 = _vertex[i].N.x;
	  t2 = _vertex[i].N.z;
	  _vertex[i].N.x = (int)(( c * t1 + s * t2) >> SIN_SHIFT);
	  _vertex[i].N.z = (int)((-s * t1 + c * t2) >> SIN_SHIFT);
	}
    }

  for(i=0; i < _nface; i++)
    {
      t1 = _face[i].N.x;
      t2 = _face[i].N.z;
      _face[i].N.x = (int)(( c * t1 + s * t2) >> SIN_SHIFT);
      _face[i].N.z = (int)((-s * t1 + c * t2) >> SIN_SHIFT);
    }
}

void Mesh::RotZ(Angle r)
{
  int i;
  long s = Sin(r),c = Cos(r);
  long t1, t2;

  for(i=0; i < _nvertex; i++)
    {
      t1 = _vertex[i].x;
      t2 = _vertex[i].y;
      _vertex[i].x = (int)(( c * t1 + s * t2) >> SIN_SHIFT);
      _vertex[i].y = (int)((-s * t1 + c * t2) >> SIN_SHIFT);

      if(_resources.Get(MR_SMOOTH))
	{
	  t1 = _vertex[i].N.x;
	  t2 = _vertex[i].N.y;
	  _vertex[i].N.x = (int)(( c * t1 + s * t2) >> SIN_SHIFT);
	  _vertex[i].N.y = (int)((-s * t1 + c * t2) >> SIN_SHIFT);
	}
    }

  for(i=0; i < _nface; i++)
    {
      t1 = _face[i].N.x;
      t2 = _face[i].N.y;
      _face[i].N.x = (int)(( c * t1 + s * t2) >> SIN_SHIFT);
      _face[i].N.y = (int)((-s * t1 + c * t2) >> SIN_SHIFT);
    }
}

void Mesh::Translate(int tx, int ty, int tz)
{
  int i;
  for(i=0; i<_nvertex; i++)
    _vertex[i].Translate(tx, ty, tz);
}

void Mesh::Scale(double sx, double sy, double sz)
{
  int i;
  for(i=0; i<_nvertex; i++)
    _vertex[i].Scale(sx, sy, sz);
}


void Mesh::Setup(PolygonEngine *PE)
{
  SetGeometry(PE->Width(), PE->Height());
  
  if(PE->Attributes().Get(GA_RGB))
    PE->Port()->Clear(20,20,20);
  else
    PE->Port()->Clear((ColorIndex)10);

  if(!_flags.Get(MF_CONVEX))
    PE->Port()->ZClear();
}

void Mesh::Draw(PolygonEngine *PE)
{
  int i,j;

  PE->PushAttributes();
  
  if(_flags.Get(MF_SMOOTH) || _flags.Get(MF_BLEND))
    PE->Attributes().Set(GA_GOURAUD);
  else
    PE->Attributes().Reset(GA_GOURAUD);

  if((!_flags.Get(MF_CONVEX)))
    PE->Attributes().Set(GA_ZBUFFER);
  else
    PE->Attributes().Reset(GA_ZBUFFER);


  PE->CommitAttributes();


  for(i=0; i<_nvertex; i++)
    Project(&_vertex[i]);


  int kaos    = (!_flags.Get(MF_CONVEX)) && (!_flags.Get(MF_CLOSED));
  int sconvex =   _flags.Get(MF_CONVEX)  && (!_flags.Get(MF_CLOSED));
  int wireframe = _flags.Get(MF_WIREFRAME);

  if(sconvex)
    for(i=0; i<_nface; i++)
      {
	if(_face[i].N.z > 0)
	  {
	    PE->VAttributes().c = _face[i].c;
	    PE->VAttributes().r = _face[i].r;
	    PE->VAttributes().g = _face[i].g;
	    PE->VAttributes().b = _face[i].b;
	    PE->Reset();

	    for(j=0; j<_face[i].nvertex; j++)
	      PE->Push(&(_face[i].vertex[j]->Projection));

	    if(wireframe)
	      PE->DrawPoly();
	    else
	      PE->FillPoly();
	  }
      }

  for(i=0; i<_nface; i++)
    {
      if(kaos || (_face[i].N.z < 0))
	{
	  PE->VAttributes().c = _face[i].c;
	  PE->VAttributes().r = _face[i].r;
	  PE->VAttributes().g = _face[i].g;
	  PE->VAttributes().b = _face[i].b;
	  PE->Reset();

	  for(j=0; j<_face[i].nvertex; j++)
	    PE->Push(&(_face[i].vertex[j]->Projection));

	  if(wireframe)
	    PE->DrawPoly();
	  else
	    PE->FillPoly();
	}
    }

  PE->PopAttributes();

}

void Mesh::Lighting(void)
{

  // This is not really the Phong model, as I don't take the
  // observer position into account, but who will notice that ?

  // Even with a Phong lighting model, the polygon engine still
  // uses Gouraud to interpolate the colors. This will be OK for
  // small polygons, but large polygons will miss some light spots,
  // because of interpolations ...
  // This will be solved by the tesselator that will subdivide
  // polygons into smaller pieces (this will be used for perspective
  // texture mapping also ...)

  // It will be easy to use this function and add ambiant lighting, fog,
  // and so on ...

  int i;
  int specular = Mode().Get(GF_SPECULAR);

  if(_flags.Get(MF_SMOOTH))
    for(i=0; i<_nvertex; i++)
      {
	int c = _L.x * _vertex[i].N.x +
	        _L.y * _vertex[i].N.y +
                _L.z * _vertex[i].N.z ;

	if(c < 0)
	  c = 0;
	else
          c >>= M_SHIFT;

	int s = 0;

	if(specular)
	  s = Specular(c);


	if(_flags.Get(MF_COLOR))
	  {
	    _vertex[i].Projection.r = (_vertex[i].r * c) >> 8;
	    _vertex[i].Projection.g = (_vertex[i].g * c) >> 8;
	    _vertex[i].Projection.b = (_vertex[i].b * c) >> 8;

	    if(specular)
	      {
		s *= _KS;

		_vertex[i].Projection.r *= _KD;
		_vertex[i].Projection.g *= _KD;	    
		_vertex[i].Projection.b *= _KD;

		_vertex[i].Projection.r += s;
		_vertex[i].Projection.g += s;
		_vertex[i].Projection.b += s;

		_vertex[i].Projection.r >>= M_SHIFT;
		_vertex[i].Projection.g >>= M_SHIFT;
		_vertex[i].Projection.b >>= M_SHIFT;
	      }
	    _vertex[i].Projection.r = Gamma(_vertex[i].Projection.r) >> (M_SHIFT - 8);
	    _vertex[i].Projection.g = Gamma(_vertex[i].Projection.g) >> (M_SHIFT - 8);
	    _vertex[i].Projection.b = Gamma(_vertex[i].Projection.b) >> (M_SHIFT - 8);
	  }
	else
	  {
	    _vertex[i].Projection.c = c;
	    if(specular)
	      {
		s *= _KS;

		_vertex[i].Projection.c *= _KD;
		_vertex[i].Projection.c += s;
		_vertex[i].Projection.c >>= M_SHIFT;
	      }
	    _vertex[i].Projection.c = Gamma((int)_vertex[i].Projection.c) >> (M_SHIFT - 6 - D_SHIFT);
	  }
      }
  else
    for(i=0; i<_nface; i++)
      {
	int c = _L.x * _face[i].N.x +
	        _L.y * _face[i].N.y +
                _L.z * _face[i].N.z ;

//	printf("%d    %d %d %d    %d %d %d    %d\n",i,_L.x,_L.y,_L.z,_face[i].N.x,_face[i].N.y,_face[i].N.z,c);
	 
	int s = 0;

	if(c<0)
	  c = 0;
	else
	  c >>= M_SHIFT;

	if(specular)
	  s = Specular(c);


	if(_flags.Get(MF_COLOR))
	  {
	    _face[i].r = (_face[i].or_ * c) >> 8;
	    _face[i].g = (_face[i].og * c) >> 8;
	    _face[i].b = (_face[i].ob * c) >> 8;

	    if(specular)
	      {
		s *= _KS;
		
		_face[i].r *= _KD;
		_face[i].g *= _KD;
		_face[i].b *= _KD;

		_face[i].r += s;
		_face[i].g += s;
		_face[i].b += s;

		_face[i].r >>= M_SHIFT;
		_face[i].g >>= M_SHIFT;
		_face[i].b >>= M_SHIFT;
	      }

	    _face[i].r = Gamma(_face[i].r) >> (M_SHIFT - 8);
	    _face[i].g = Gamma(_face[i].g) >> (M_SHIFT - 8);
	    _face[i].b = Gamma(_face[i].b) >> (M_SHIFT - 8);
	  }
	else
	  {
	    _face[i].c = c;
	    if(specular)
	      {
		s *= _KS;
		_face[i].c *= _KD;
		_face[i].c += s;
		_face[i].c >>= M_SHIFT;
	      }
	    _face[i].c = Gamma((int)_face[i].c) >> (M_SHIFT - 6 - D_SHIFT);
	  }
	 // printf("%d     %d %d %d   %d\n",i,_face[i].r, _face[i].g, _face[i].b, _face[i].c);
      }
}

void Mesh::ResetColors(void)
{
  int i;

  if(_flags.Get(MF_SMOOTH))
    for(i=0; i<_nvertex; i++)
      {
	if(_flags.Get(MF_COLOR))
	  {
	    _vertex[i].Projection.r = _vertex[i].r;
	    _vertex[i].Projection.g = _vertex[i].g;
	    _vertex[i].Projection.b = _vertex[i].b;

	    _vertex[i].Projection.r = Gamma(_vertex[i].Projection.r) >> (M_SHIFT - 8);
	    _vertex[i].Projection.g = Gamma(_vertex[i].Projection.g) >> (M_SHIFT - 8);
	    _vertex[i].Projection.b = Gamma(_vertex[i].Projection.b) >> (M_SHIFT - 8);
	  }
      }
  else
    for(i=0; i<_nface; i++)
      {
	if(_flags.Get(MF_COLOR))
	  {
	    _face[i].r = _face[i].or_;
	    _face[i].g = _face[i].og;
	    _face[i].b = _face[i].ob;

	    _face[i].r = Gamma(_face[i].r) >> (M_SHIFT - 8);
	    _face[i].g = Gamma(_face[i].g) >> (M_SHIFT - 8);
	    _face[i].b = Gamma(_face[i].b) >> (M_SHIFT - 8);
	  }
      }
}



void Mesh::InvertNormals(void)
{
  int i;
  
  for(i=0; i < _nface; i++)
    {
      _face[i].N.x = -_face[i].N.x;
      _face[i].N.y = -_face[i].N.y;
      _face[i].N.z = -_face[i].N.z;
    }

  if(_resources.Get(MR_SMOOTH))
    for(i=0; i < _nvertex; i++)
      {
	_vertex[i].N.x = -_vertex[i].N.x;
	_vertex[i].N.y = -_vertex[i].N.y;
	_vertex[i].N.z = -_vertex[i].N.z;
      }

}

void Mesh::ComputeNormals(void)
{
  int i; 
  VectorF A,B,N;
  double k;
  int i0, i1, i2;

  for(i=0; i < _nface; i++)
    {
      
      N.x = 0;
      N.y = 0;
      N.z = 0;

      for(i0 = 0; i0 < _face[i].nvertex; i0++)
	{

	  i1 = (i0 + 1) % _face[i].nvertex;
	  i2 = (i1 + 1) % _face[i].nvertex;

	  A.x = _face[i].vertex[i0]->x - 
	        _face[i].vertex[i1]->x;  
	  A.y = _face[i].vertex[i0]->y - 
	        _face[i].vertex[i1]->y;  
	  A.z = _face[i].vertex[i0]->z - 
	        _face[i].vertex[i1]->z;  
      
	  B.x = _face[i].vertex[i2]->x - 
	        _face[i].vertex[i1]->x;  
	  B.y = _face[i].vertex[i2]->y - 
	        _face[i].vertex[i1]->y;  
	  B.z = _face[i].vertex[i2]->z - 
	        _face[i].vertex[i1]->z;  

	  N.x += A.y*B.z - A.z*B.y;
	  N.y += A.z*B.x - A.x*B.z;
	  N.z += A.x*B.y - A.y*B.x;
	  
	}

      k = N.x * N.x + N.y * N.y + N.z * N.z;
      k = k ? (double)M_BIG / sqrt(k) : 0.0;

      N.x *= k;
      N.y *= k;
      N.z *= k;

      _face[i].N.x = (int)N.x;
      _face[i].N.y = (int)N.y;
      _face[i].N.z = (int)N.z;
    }
}

inline int Mesh::InFace(MFace *F, MVertex *V)
{
  int i;
  for(i=0; i<F->nvertex; i++)
    if(F->vertex[i] == V)
      return 1;
  return 0;
}

void Mesh::Smooth(void)
{
  int i,j;
  for(i=0; i<_nvertex; i++)
    {
      _vertex[i].N.x = 0;
      _vertex[i].N.y = 0;
      _vertex[i].N.z = 0;
    }

  for(i=0; i<_nface; i++)
    for(j=0; j<_face[i].nvertex; j++)
      {
	_face[i].vertex[j]->N.x += _face[i].N.x;
	_face[i].vertex[j]->N.y += _face[i].N.y;
	_face[i].vertex[j]->N.z += _face[i].N.z;
      }

  for(i=0; i<_nvertex; i++)
    _vertex[i].N.Normalize();

  _resources.Set(MR_SMOOTH);
}

void Mesh::Blend(void)
{
  int i;
  int j;

  for(i=0; i<_nvertex; i++)
    {
      _vertex[i].r     = 0;
      _vertex[i].g     = 0;
      _vertex[i].b     = 0;
      _vertex[i].count = 0;
    }

  for(i=0; i<_nface; i++)
    for(j=0; j<_face[i].nvertex; j++)
      {
	_face[i].vertex[j]->r += _face[i].or_;
	_face[i].vertex[j]->g += _face[i].og;
	_face[i].vertex[j]->b += _face[i].ob;
	_face[i].vertex[j]->count++;
      }

  for(i=0; i<_nvertex; i++)
    if(_vertex[i].count)
      {
	_vertex[i].r /= _vertex[i].count;
	_vertex[i].g /= _vertex[i].count;
	_vertex[i].b /= _vertex[i].count;
      }
  _resources.Set(MR_BLEND);
}


void
Mesh::White(void)
{
   int i;
   for(i=0; i<_nface; i++)
      _face[i].or_ = _face[i].og = _face[i].ob = 255;
   
  for(i=0; i<_nvertex; i++)
    {
      _vertex[i].r     = 255;
      _vertex[i].g     = 255;
      _vertex[i].b     = 255;
    }
   
   _resources.Set(MR_COLORS);
   _resources.Set(MR_BLEND);
}

void
Mesh::EnvironMap(void)
{
  int i; 
  for(i=0; i<_nvertex; i++)
     {
	_vertex[i].Projection.X = (M_BIG - _vertex[i].N.x) * size / (M_BIG * 2);
	_vertex[i].Projection.Y = (M_BIG - _vertex[i].N.y) * size / (M_BIG * 2);
	
	if(_vertex[i].Projection.X < 0)
	   _vertex[i].Projection.X = 0;
	
	if(_vertex[i].Projection.Y < 0)
	   _vertex[i].Projection.Y = 0;	
     }
}

void
Mesh::TextureMap(char axis, float mult)
{
   int i;
   
   
   switch(axis)
     {
      case 'x':
      case 'X':

	for(i=0; i<_nvertex; i++)
	  {
	     _vertex[i].Projection.X = (int)(mult * (10000.0 + (float)_vertex[i].y)
					       * (float)size / 20000.0);
	     _vertex[i].Projection.Y = (int)(mult * (10000.0 + (float)_vertex[i].z)
					       * (float)size / 20000.0);
	  }	
	
	
	break;
	
      case 'y':
      case 'Y':
	
	for(i=0; i<_nvertex; i++)
	  {
	     _vertex[i].Projection.X = (int)(mult * (10000.0 + (float)_vertex[i].x)
					       * (float)size / 20000.0);
	     _vertex[i].Projection.Y = (int)(mult * (10000.0 + (float)_vertex[i].y)
					       * (float)size / 20000.0);
	  }	
	

	break;
	
      case 'z':
      case 'Z':

	for(i=0; i<_nvertex; i++)
	  {
	     _vertex[i].Projection.X = (int)(mult * (10000.0 + (float)_vertex[i].x)
					       * (float)size / 20000.0);
	     _vertex[i].Projection.Y = (int)(mult * (10000.0 + (float)_vertex[i].y)
					       * (float)size / 20000.0);
	  }	
	
	break;	


     }
}

/*************************************************************************************/

int check_eof(FIL& input,  Mesh& M)
{
  int retval = 0;
  if(f_eof(&input))
    {
      M._error_code = ME_EOF;
      retval = 1;
    }
  return retval;
}


static char my_fgetc(FIL* input) {
    char result;
    UINT br;
    f_read(input, &result, 1, &br);
    return result;
}

static inline int my_is_space(char c) {
    return c == ' ' || c == 10 || c == 13 || c == '\t';
}

static char* my_fgets(FIL* input) {
    static char buff[255];
    char c;
    while(my_is_space(c = my_fgetc(input)));
    char* ptr = buff;
    *ptr++ = c;
    while(!my_is_space(c = my_fgetc(input))) {
	*ptr++ = c;
    }
    *ptr = '\0';
    return buff;
}

static int read_int(FIL& input) {
    int result = atoi(my_fgets(&input));
//  printf("read int: %d\n",result);
    return result;
}

static float read_float(FIL& input) {
    float result = atof(my_fgets(&input));
//  printf("read float: %d\n",(int)(result * 100000));
    return result;
}


void Mesh::load_geometry(const char* filename) {
  Mesh& M = *this;
  FIL input;
   
  int dummy;
  VectorF *vertexf;
  int i;
  int j;

   
  (void)dummy; // silence a warning.
   
  if(f_open(&input, filename, FA_READ) != FR_OK) {
     printf("could not open file: %s\n",filename);
     M._error_code = ME_EOF;
     return;
  }
   
   
  if(!M._resources.Get(MR_VERTICES))
    {

      if(check_eof(input, M))
	return;

      if(verbose)
	 printf("loading object geometry ...\n");

      M._nvertex = read_int(input);

      if(!(M._vertex = new MVertex[M._nvertex]))
	{
	  M._error_code = ME_MALLOC;
	  return;
	}

      M._resources.Set(MR_VERTICES);

      if(check_eof(input, M))
	return;

      M._nface = read_int(input);
      if(!(M._face = new MFace[M._nface]))
	{
	  M._error_code = ME_MALLOC;
	  return;
	}

      M._resources.Set(MR_FACES);
      
      dummy = read_int(input);

      if(!(vertexf = new VectorF[M._nvertex]))
	{
	  M._error_code = ME_MALLOC;
	  return;
	}

      if(verbose)
	{
	   printf("loading object ...\n");
	   printf("nvertex= %d\n",M._nvertex);
           printf("nface  = %d\n",M._nface);
	}

       for(i=0; i<M._nvertex; i++)
	 {
	    if(check_eof(input, M)) {
		return;
	    }
	   vertexf[i].x = read_float(input);
	   vertexf[i].y = read_float(input);
	   vertexf[i].z = read_float(input);
	}

      for(i=0; i<M._nface; i++)
	{
	  if(check_eof(input, M))
	    return;
	  
	  M._face[i].nvertex = read_int(input);

	  if(!(M._face[i].vertex = new MVertex*[M._face[i].nvertex]))
	    {
	      M._error_code = ME_MALLOC;
	      return;
	    }
	  
	  for(j=0; j<M._face[i].nvertex; j++)
	    {
	      int idx;
	      idx = read_int(input);
	      M._face[i].vertex[M._face[i].nvertex - j - 1] = 
		                       &(M._vertex[idx - 1]);
	    }
	}

      if(verbose) {   }
          printf("center and scale ...\n");

	  VectorF C(0.0, 0.0, 0.0);
      for(i=0; i<M._nvertex; i++)
	{
	  C.x += vertexf[i].x;
	  C.y += vertexf[i].y;
	  C.z += vertexf[i].z;
	}

      if(M._nvertex)
	{
	  C.x /= (double)M._nvertex;
	  C.y /= (double)M._nvertex;
	  C.z /= (double)M._nvertex;
	}

       if(verbose)
	 printf("center = [ %d %d %d]\n",(int)(C.x*1000), (int)(C.y*1000), (int)(C.z*1000));
  
      float r = 0,r2;
      
      for(i=0; i<M._nvertex; i++)
	{
	  vertexf[i].x -= C.x;
	  vertexf[i].y -= C.y;
	  vertexf[i].z -= C.z;
	  
	  r2 = vertexf[i].x * vertexf[i].x + 
	       vertexf[i].y * vertexf[i].y + 
	       vertexf[i].z * vertexf[i].z ;
	  
	  r = (r2 > r) ? r2 : r;
	}
      
      r = sqrt(r);

       if(verbose)
	 printf("object radius = %d\n", (int)(r*1000));

      double scaling_factor = r ? 10000.0 / r : 0.0;

//      if(verbose)
//	cerr << "scaling factor = " << scaling_factor << endl;

      for(i=0; i<M._nvertex; i++)
	{
	  vertexf[i].x *= scaling_factor;
	  vertexf[i].y *= scaling_factor;
	  vertexf[i].z *= scaling_factor;
	}
      
      if(verbose)
	 printf("converting to TAGL++ Mesh\n");

      for(i=0; i<M._nvertex; i++)
	{
	  M._vertex[i].x =     (int)vertexf[i].z;
	  M._vertex[i].y =   - (int)vertexf[i].y;
	  M._vertex[i].z =     (int)vertexf[i].x;
	}

      delete[] vertexf;

      if(verbose)
	 printf("computing normals ...\n");

      M.ComputeNormals();
      
      if(verbose)
	 printf("sucessfully loaded.\n");

    }
/*  
  else
    {
      int ncolor;
      int nface;
      ColorF *colorf;

      if(verbose)
	cerr << "loading object colors ..." << endl;
      
      if(check_eof(input, M))
	return input;

      input >> ncolor >> nface;

      if(verbose)
	cerr << ncolor << " color entries" << endl;

      if(nface != M._nface)
	{
	  M._error_code = ME_MATCH;
	  return input;
	}

      if(!(colorf = new ColorF[ncolor]))
	{
	  M._error_code = ME_MALLOC;
	  return input;
	}

      for(i=0; i<ncolor; i++)
	{
	  if(check_eof(input, M))
	    return input;
	  input >> colorf[i].r >> colorf[i].g >> colorf[i].b;
	}
      
      for(i=0; i<nface; i++)
	{
	  int idx;

	  if(check_eof(input, M))
	    return input;

	  input >> idx;
	  M._face[i].or_ = (int)(colorf[idx - 1].r * 255.0);
	  M._face[i].og = (int)(colorf[idx - 1].g * 255.0);
	  M._face[i].ob = (int)(colorf[idx - 1].b * 255.0);
	}

      delete[] colorf;

      if(verbose)
	cerr << "sucessfully loaded" << endl;

      M._resources.Set(MR_COLORS);
    }
*/
 }

void Mesh::load_colors(const char* filename) {
   // TODO
}

