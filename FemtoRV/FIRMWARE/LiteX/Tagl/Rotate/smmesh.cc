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
 * smmesh.cc
 *
 */

#include "smmesh.h"

SmoothMesh::SmoothMesh(Mesh *m)
{
  int i;
  for(i=0; i<m->_nface; i++)
    if(m->_face[i].nvertex != 3)
      {
	_error_code = SME_TRI;
	printf("SmoothMesh: invalid n-sided face\n");
	return;
      }
  
  if(!m->Resources().Get(MR_SMOOTH))
    m->Smooth();


  _sm_face   = new SmoothTriangle[m->_nface];
  _n_sm_face = m->_nface;

  _resources.Set(SMR_FACE);

  for(i=0; i<_n_sm_face; i++)
    {
      VectorF P0, P1, P2, N0, N1, N2;
      P0 << *(m->_face[i].vertex[0]);
      P1 << *(m->_face[i].vertex[1]);      
      P2 << *(m->_face[i].vertex[2]);
      N0 <<  m->_face[i].vertex[0]->N;
      N1 <<  m->_face[i].vertex[1]->N;      
      N2 <<  m->_face[i].vertex[2]->N;
      _sm_face[i].Update(P0, P1, P2, N0, N1, N2);
    }

  _resources.Set(MR_COLORS);

}

void 
SmoothMesh::RotX(Angle r)
{
  int i;
  for(i=0; i<_n_sm_face; i++)
    _sm_face[i].RotX(r);
}

void 
SmoothMesh::RotY(Angle r)
{
  int i;
  for(i=0; i<_n_sm_face; i++)
    _sm_face[i].RotY(r);
}
 

void 
SmoothMesh::RotZ(Angle r)
{
  int i;
  for(i=0; i<_n_sm_face; i++)
    _sm_face[i].RotZ(r);
}


void 
SmoothMesh::Translate(int tx, int ty, int tz)
{
  int i;
  for(i=0; i<_n_sm_face; i++)
    _sm_face[i].Translate(tx, ty, tz);
}

void 
SmoothMesh::Scale(double sx, double sy, double sz)
{
  int i;
  for(i=0; i<_n_sm_face; i++)
    _sm_face[i].Scale(sx, sy, sz);
}

void 
SmoothMesh::Shiny(gfloat factor, gfloat lambertian, gfloat specular)
{
  int i;
  for(i=0; i<_n_sm_face; i++)
    _sm_face[i].Shiny(factor, lambertian, specular);
}

void 
SmoothMesh::Dull()
{
  int i;
  for(i=0; i<_n_sm_face; i++)
    _sm_face[i].Dull();
}


void 
SmoothMesh::Draw(PolygonEngine *PE)
{
  int i;
  for(i=0; i<_n_sm_face; i++)
    {
      _sm_face[i].Mode() = Mode();
      PE << _sm_face[i];
    }
}

void 
SmoothMesh::Lighting(void)
{
  int i;
  for(i=0; i<_n_sm_face; i++)
    _sm_face[i].Lighting();
}

SmoothMesh::~SmoothMesh(void)
{
  if(_resources.Get(SMR_FACE))
    delete[] _sm_face;
}
