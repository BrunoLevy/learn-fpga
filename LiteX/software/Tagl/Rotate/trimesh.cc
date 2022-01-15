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
 * trimesh.cc
 *
 */

#include "trimesh.h"

TriMesh::TriMesh(VectorF& P0, VectorF& P1, VectorF& P2, int n)
{
  int i,j;


  _P0 = P0;
  _P1 = P1;
  _P2 = P2;

  _n = n;

  _nvertex = _n*(_n+1)/2;
  if(!(_vertex = new MVertex[_nvertex]))
	{
	  _error_code = ME_MALLOC;
	  return;
	}

  _resources.Set(MR_VERTICES);


  _nface = _n*(_n-1)/2 + (_n-1)*(_n-2)/2;
  if(!(_face = new MFace[_nface]))
	{
	  _error_code = ME_MALLOC;
	  delete[] _vertex;
	  return;
	}

  _resources.Set(MR_FACES);

  _N.x = (_P2.y - _P1.y) * (_P0.z - _P1.z) - (_P0.y - _P1.y) * (_P2.z - _P1.z);
  _N.y = (_P2.z - _P1.z) * (_P0.x - _P1.x) - (_P0.z - _P1.z) * (_P2.x - _P1.x);
  _N.z = (_P2.x - _P1.x) * (_P0.y - _P1.y) - (_P0.x - _P1.x) * (_P2.y - _P1.y);

  _N.Normalize();

  for(i=0; i<_n; i++)
    for(j=0; j<=_n-1-i; j++)
      {
	VectorF V;
	TVertex(V, i, j, _n-1-i-j, 0);
	_vertex[TIndex(i,j)] << V;
      }

  
  int index = 0;
  for(i=0; i<_n-1; i++)
    for(j=0; j<_n-1-i; j++)
	{
	  _face[index].nvertex = 3;
	  _face[index].vertex  = new MVertex*[3];
	  _face[index].vertex[0] = &_vertex[TIndex(i  , j  )];
	  _face[index].vertex[1] = &_vertex[TIndex(i+1, j  )];
	  _face[index].vertex[2] = &_vertex[TIndex(i  , j+1)];

	  index++;
	}

  for(i=1; i<_n-1; i++)
    for(j=0; j<_n-1-i; j++)
	{
	  _face[index].nvertex = 3;
	  _face[index].vertex  = new MVertex*[3];
	  _face[index].vertex[0] = &_vertex[TIndex(i  , j  )];
	  _face[index].vertex[1] = &_vertex[TIndex(i  , j+1)];
	  _face[index].vertex[2] = &_vertex[TIndex(i-1, j+1)];

	  index++;
	}

  ComputeNormals();
  Smooth();
}

void 
TriMesh::RotX(Angle r)
{
  Mesh::RotX(r);
  _P0.RotX(r);
  _P1.RotX(r);
  _P2.RotX(r);
  _N.RotX(r);
}

void 
TriMesh::RotY(Angle r)
{
  Mesh::RotY(r);
  _P0.RotY(r);
  _P1.RotY(r);
  _P2.RotY(r);
  _N.RotY(r);
}

void 
TriMesh::RotZ(Angle r)
{
  Mesh::RotZ(r);
  _P0.RotZ(r);
  _P1.RotZ(r);
  _P2.RotZ(r);
  _N.RotZ(r);
}

void 
TriMesh::Translate(int tx, int ty, int tz)
{
  Mesh::Translate(tx, ty, tz);
  _P0.Translate(tx, ty, tz);
  _P1.Translate(tx, ty, tz);
  _P2.Translate(tx, ty, tz);
}

void 
TriMesh::Scale(double sx, double sy, double sz)
{
  Mesh::Scale(sx, sy, sz);
  _P0.Scale(sx, sy, sz);
  _P1.Scale(sx, sy, sz);
  _P2.Scale(sx, sy, sz);
  _N.Scale(sx, sy, sz);
  _N.Normalize();
}
