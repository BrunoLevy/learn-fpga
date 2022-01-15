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
 * bezier.cc
 *
 */

#include <math.h>
#include "bezier.h"


void 
Bezier::Draw(PolygonEngine *PE)
{
  if(Mode().Get(BF_PATCH))
    TriMesh::Draw(PE);

  if(Mode().Get(BF_CONTROL) && _control)
    {
      _control->Mode() = Mode();
      _control->Mode().Set(MF_WIREFRAME);
      _control->Draw(PE);
    }

  if(Mode().Get(BF_BASE))
    {
      MVertex P0, P1, P2;

      PE->PushAttributes();
      PE->Attributes().Reset(GA_GOURAUD);
      if(!Mode().Get(MF_CONVEX))
	PE->Attributes().Set(GA_ZBUFFER);
      else
	PE->Attributes().Reset(GA_ZBUFFER);

      PE->CommitAttributes();

      PE->VAttributes().c = 63 << D_SHIFT;
      PE->VAttributes().r = 255;
      PE->VAttributes().g = 255;
      PE->VAttributes().b = 255;

      P0 << _P0;
      P1 << _P1;
      P2 << _P2;

      Project(&P0);
      Project(&P1);
      Project(&P2);

      PE->Reset();
      PE->Push(&(P0.Projection));
      PE->Push(&(P1.Projection));
      PE->Push(&(P2.Projection));
      PE->DrawPoly();

      PE->PopAttributes();
    }
}

void 
Bezier::RotX(Angle r)
{
  if(_control)
      _control->RotX(r);
  TriMesh::RotX(r);
}

void 
Bezier::RotY(Angle r)
{
  if(_control)
      _control->RotY(r);
  TriMesh::RotY(r);
}

void 
Bezier::RotZ(Angle r)
{
  if(_control)
      _control->RotZ(r);
  TriMesh::RotZ(r);
}

void 
Bezier::Translate(int tx, int ty, int tz)
{
  if(_control)
      _control->Translate(tx, ty, tz);
  TriMesh::Translate(tx, ty, tz);
}

void 
Bezier::Scale(double sx, double sy, double sz)
{
  if(_control)
      _control->Scale(sx, sy, sz);
  TriMesh::Scale(sx, sy, sz);
}



inline bnumber Pow(bnumber x, int n)
{
  bnumber result = 1.0;
  int i;
  for(i=0; i<n; i++)
    result *= x;

  return result;
}

inline bnumber fact(int n)
{
  bnumber result = 1;
  int i;

  for(i=2; i<=n; i++)
    result *= (bnumber)i;

  return result;
}


bnumber 
Bezier::Bernstein(int     i, int     j, int     k,
                  bnumber u, bnumber v, bnumber w)
{
return Bernstein(_degree, i, j, k, u, v, w);
}

bnumber   
Bezier::Bernstein(int n, int i, int j, int k, 
		  bnumber u, bnumber v, bnumber w)
{
  return fact(n) / (fact(i)*fact(j)*fact(k)) 
      * Pow(u,i) * Pow(v,j) * Pow(w,k);
}

bnumber 
Bezier::BezierPoly(bnumber *b, bnumber u, bnumber v, bnumber w)
{
  int i,j;
  bnumber result = 0;

  if(!b)
    return 0.0;

  for(i=0; i<=_degree; i++)
    for(j=0; j<=_degree-i; j++)
      result += b[TIndex(_degree+1,i,j)] * Bernstein(i,j,_degree-i-j,u,v,w);

  return result;
}

VectorF
Bezier::BezierPoly(VectorF *b, bnumber u, bnumber v, bnumber w)
{
  int i,j;
  VectorF result = 0.0;

  for(i=0; i<=_degree; i++)
    for(j=0; j<=_degree-i; j++)
        result += Bernstein(i,j,_degree-i-j,u,v,w) *
	          b[TIndex(_degree+1,i,j)];
  return result;
}


VectorF  
Bezier::DaBezier(VectorF *b, bnumber u,  bnumber v,  bnumber w,
		 bnumber a1, bnumber a2, bnumber a3)
{
    int i,j;
    VectorF result = 0.0;
    
    for(i=0; i<=_degree-1; i++)
	for(j=0; j<=_degree-i-1; j++)
	    result += Bernstein(_degree-1, i, j, _degree-1-i-j, u, v, w) *
		      (
			  a1 * b[TIndex(_degree+1,i+1,j  )] +
			  a2 * b[TIndex(_degree+1,i  ,j+1)] +
			  a3 * b[TIndex(_degree+1,i  ,j  )]
		      );
    
    result *= (float)_degree;
    return result;
}

VectorF
Bezier::Normal(VectorF *b, bnumber u, bnumber v, bnumber w)
{
    VectorF V1 = DaBezier(b, u, v, w, -1.0,  2.0, -1.0);
    VectorF V2 = DaBezier(b, u, v, w, -1.0, -1.0,  2.0);
    return V2 ^ V1;
}

void
Bezier::Update(VectorF *b)
{
  int i,j;

  if(!b)
    {
      Update((bnumber *)NULL);
      return;
    }

  for(i=0; i<_n; i++)
    for(j=0; j<=_n-1-i; j++)
      {
	bnumber u = (bnumber)i/(bnumber)(_n - 1);
	bnumber v = (bnumber)j/(bnumber)(_n - 1);
	bnumber w = 1.0 - u - v;
	VectorF V = BezierPoly(b, u, v, w);
	_vertex[TIndex(_n, i, j)] << V;
	VectorF N = Normal(b, u, v, w);
	_vertex[TIndex(_n, i, j)].N << N;
	_vertex[TIndex(_n, i, j)].N.Normalize();
      }

  _resources.Set(MR_SMOOTH);

  ComputeNormals();

  if(_control)
      {
	  for(i=0; i<=_degree; i++)
	      for(j=0; j<=_degree-i; j++)
		  _control->Vertex()[TIndex(_degree+1,i,j)] << 
		      b[TIndex(_degree+1,i,j)];

	  _control->ComputeNormals();
      }

}

void 
Bezier::Update(bnumber* b)
{
  int i,j;

  for(i=0; i<_n; i++)
    for(j=0; j<=_n-1-i; j++)
      {
	VectorF V;
	bnumber u = (bnumber)i/(bnumber)(_n - 1);
	bnumber v = (bnumber)j/(bnumber)(_n - 1);
	bnumber w = 1.0 - u - v;
	TVertex(2, V, u, v, w, BezierPoly(b, u, v, w));
	_vertex[TIndex(_n, i,j)] << V;
      }

  ComputeNormals();
  Smooth();

  if(_control)
      {
	  for(i=0; i<=_degree; i++)
	      for(j=0; j<=_degree-i; j++)
		  {
		      VectorF V;
		      bnumber u = (bnumber)i/(bnumber)(_degree);
		      bnumber v = (bnumber)j/(bnumber)(_degree);
		      bnumber w = 1.0 - u - v;
		      if(b)
			  TVertex(2, V, u, v, w, b[TIndex(_degree+1,i,j)]);	
		      else
			  TVertex(2, V, u, v, w, 0.0);	
		      _control->Vertex()[TIndex(_degree+1,i,j)] << V;
		  }
	  _control->ComputeNormals();
      }
}

void Bezier::Update(VectorF& P0, VectorF& P1, VectorF& P2)
{
  _P0 = P0;
  _P1 = P1;
  _P2 = P2;
  Update((bnumber*)NULL);
}

void 
Bezier::DegreeElevation(VectorF *b_in, VectorF *b_out)
{
    int i,j,k;
    bnumber u,v,w;

    for(i=0; i<=_degree+1; i++)
	for(j=0; j<=_degree+1-i; j++)
	    {
		k = _degree+1-i-j;

		u = (bnumber) i / (bnumber)(_degree+1);
		v = (bnumber) j / (bnumber)(_degree+1);
		w = (bnumber) k / (bnumber)(_degree+1);

		b_out[TIndex(_degree+2,i,j)] = 0.0;

		if(i>0 && (j <= _degree+1))
		    b_out[TIndex(_degree+2,i,j)] += 
			u * b_in[TIndex(_degree+1,i-1,j)];

		if(j>0 && (i <= _degree+1))
		    b_out[TIndex(_degree+2,i,j)] += 
			v * b_in[TIndex(_degree+1,i,j-1)];

		if(k>0 && (i <= _degree+1) && (j <= _degree+1))
		    b_out[TIndex(_degree+2,i,j)] += 
			w * b_in[TIndex(_degree+1,i,j)];
	    }

    _degree++;

    if(_control)
	{
	    delete _control;
	    _control = new TriMesh(_P0, _P1, _P2, _degree+1);
	    Update(b_out);
	    
	    for(i=0; i<_control->NFace(); i++)
		{
		    _control->Face()[i].c  = 63 << D_SHIFT;
		    _control->Face()[i].r = 255;
		    _control->Face()[i].g = 0;
		    _control->Face()[i].b = 0;
		}

	    for(i=0; i<_control->NVertex(); i++)
		{
		    _control->Vertex()[i].Projection.c = 63 << D_SHIFT;
		    _control->Vertex()[i].Projection.r = 255;
		    _control->Vertex()[i].Projection.g = 0;
		    _control->Vertex()[i].Projection.b = 0;
		}

	    _control->Resources().Set(MR_COLORS);
	    _control->ComputeNormals();
	}

}

Bezier::Bezier(
	       VectorF& P0, VectorF& P1, VectorF& P2,
	       bnumber* b,
	       int degree,
	       int n,
               int control
	       ) : TriMesh(P0, P1, P2, n)
{

  int i;
  _degree  = degree;
  _control = control ? new TriMesh(P0, P1, P2, _degree+1) : (TriMesh *)NULL;
  Update(b);
  for(i=0; i<_nface; i++)
    {
      _face[i].or_ = 255;
      _face[i].og = 255;
      _face[i].ob = 0;
    }
  _resources.Set(MR_COLORS);
  Blend();

  if(_control)
      {
	  for(i=0; i<_control->NFace(); i++)
	      {
		  _control->Face()[i].c  = 63 << D_SHIFT;
		  _control->Face()[i].r = 255;
		  _control->Face()[i].g = 0;
		  _control->Face()[i].b = 0;
	      }

	  for(i=0; i<_control->NVertex(); i++)
	      {
		  _control->Vertex()[i].Projection.c = 63 << D_SHIFT;
		  _control->Vertex()[i].Projection.r = 255;
		  _control->Vertex()[i].Projection.g = 0;
		  _control->Vertex()[i].Projection.b = 0;
	      }

	  _control->Resources().Set(MR_COLORS);
      }

  Mode().Set(BF_PATCH);
}

Bezier::~Bezier(void)
{
  if(_control)
      delete _control;
}

void 
Bezier::FlatControl(VectorF *b)
{
  double u,v,w;

  for(u=0; u<=_degree; u++)
    for(v=0; v<=_degree-u; v++)
      {
	w = _degree - u - v;
	TVertex(_degree+1, b[TIndex(_degree+1, (int)u, (int)v)], u, v, w, 0.0);
      }

}
