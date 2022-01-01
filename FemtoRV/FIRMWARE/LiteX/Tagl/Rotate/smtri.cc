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
 * smtri.cc
 *
 */

#include "smtri.h"


inline void
project(VectorF& M, VectorF& M0, VectorF& N, double radius = 0.0)
{
  double k = 1.0/(N.x*N.x+N.y*N.y+N.z*N.z) * 
             (
             N.x * (M0.x - M.x) +
             N.y * (M0.y - M.y) +
             N.z * (M0.z - M.z) 
             );
  VectorF MM = M;
  MM.x += k*N.x;
  MM.y += k*N.y;
  MM.z += k*N.z;
  VectorF D = MM;
  D -= M0;
  if(radius > 0.0)
      {
	  D.Normalize();
	  D *= radius;
      }
  D += M0;
  M = D;
  
}

SmoothTriangle::SmoothTriangle(void)
{
  VectorF P0, P1, P2;

  P0.x =  -0.5;
  P0.z =  -0.5;
  P0.y =   0.0;

  P1.x =  0.5;
  P1.z = -0.5;
  P1.y =  0.0;
  
  P2.x =  0.0;
  P2.z =  0.5;
  P2.y =  0.0;


  VectorF P;
  P.x = (P0.x + P1.x + P2.x) / 3.0;
  P.y = (P0.y + P1.y + P2.y) / 3.0;
  P.z = (P0.z + P1.z + P2.z) / 3.0;
  
  _T0 = new Bezier(P0, P1, P, NULL, 3, 5);
  _T1 = new Bezier(P1, P2, P, NULL, 3, 5);
  _T2 = new Bezier(P2, P0, P, NULL, 3, 5);


  _resources.Set(MR_COLORS);
  Mode().Set(BF_PATCH);

}


SmoothTriangle::SmoothTriangle(VectorF P0, VectorF P1, VectorF P2)
{

  VectorF P;
  P.x = (P0.x + P1.x + P2.x) / 3.0;
  P.y = (P0.y + P1.y + P2.y) / 3.0;
  P.z = (P0.z + P1.z + P2.z) / 3.0;
  
  _T0 = new Bezier(P0, P1, P, NULL, 3, 10);
  _T1 = new Bezier(P1, P2, P, NULL, 3, 10);
  _T2 = new Bezier(P2, P0, P, NULL, 3, 10);


  _resources.Set(MR_COLORS);
  Mode().Set(BF_PATCH);

}

SmoothTriangle::SmoothTriangle(VectorF P0, VectorF P1, VectorF P2, 
			       VectorF N0, VectorF N1, VectorF N2)
{
  VectorF P = (1.0 / 3.0) * (P0 + P1 + P2);
  
  _T0 = new Bezier(P1, P2, P, NULL, 3, 10);
  _T1 = new Bezier(P2, P0, P, NULL, 3, 10);
  _T2 = new Bezier(P0, P1, P, NULL, 3, 10);


  _resources.Set(MR_COLORS);
  Mode().Set(BF_PATCH);

  Update(P0, P1, P2, N0, N1, N2);
}

void SmoothTriangle::Update(VectorF P0, VectorF P1, VectorF P2, 
			    VectorF N0, VectorF N1, VectorF N2)
{
  VectorF P;
  VectorF control0[10];
  VectorF control1[10];
  VectorF control2[10];
//  VectorF Control0[15];
//  VectorF Control1[15];
//  VectorF Control2[15];
  VectorF P01, P12, P20;
  VectorF N01, N12, N20;
  VectorF tmp;
  double l01, l12, l20;
  double l0,   l1,    l2;
  double l0p, l1p, l2p;
  double radius;


  P01 =  (P0 + P1) / 2.0;
  P12 =  (P1 + P2) / 2.0;
  P20 =  (P2 + P0) / 2.0;

  N01 = (N0 + N1) / 2.0;
  N12 = (N1 + N2) / 2.0;
  N20 = (N2 + N0) / 2.0;

  P = (P0 + P1 + P2) / 3.0;

  l0 = (P - P0).Length();
  l1 = (P - P1).Length();
  l2 = (P - P2).Length();

  l01  = (P1 - P0).Length();
  l12  = (P2 - P1).Length();
  l20  = (P2 - P0).Length();

  l0p = (P - (P1 + P2) / 2.0).Length();
  l1p = (P - (P2 + P0) / 2.0).Length();
  l2p = (P - (P0 + P1) / 2.0).Length();

  _T0->Update(P1, P2, P);
  _T1->Update(P2, P0, P);
  _T2->Update(P0, P1, P);

  _T0->FlatControl(control0);
  _T1->FlatControl(control1);
  _T2->FlatControl(control2);

// -------------------------------------------------
// Control nodes surrounding base triangle vertice 
// -------------------------------------------------

  radius = 0.33 * l1   ;
  project(control0[TriMesh::TIndex(4,2,0)], P1, N1, radius);
  radius = 0.33 * l12 ;
  project(control0[TriMesh::TIndex(4,2,1)], P1, N1, radius);
  project(control0[TriMesh::TIndex(4,1,2)], P2, N2, radius);
  radius = 0.33 * l2  ;
  project(control0[TriMesh::TIndex(4,0,2)], P2, N2, radius); 

  radius = 0.33 * l2  ;
  project(control1[TriMesh::TIndex(4,2,0)], P2, N2, radius);
  radius = 0.33 * l20 ;
  project(control1[TriMesh::TIndex(4,2,1)], P2, N2, radius);
  project(control1[TriMesh::TIndex(4,1,2)], P0, N0, radius);
  radius = 0.33 * l0 ;
  project(control1[TriMesh::TIndex(4,0,2)], P0, N0, radius);

  radius = 0.33 * l0  ;
  project(control2[TriMesh::TIndex(4,2,0)], P0, N0, radius);
  radius = 0.33 * l01 ;
  project(control2[TriMesh::TIndex(4,2,1)], P0, N0, radius);
  project(control2[TriMesh::TIndex(4,1,2)], P1, N1, radius);
  radius = 0.33 * l1  ;
  project(control2[TriMesh::TIndex(4,0,2)], P1, N1, radius);


// -------------------------------------------------
// Three center control nodes
// -------------------------------------------------

  VectorF AB, V, N, M;

  radius = 0.5 * l0p ;
  AB  = control0[TriMesh::TIndex(4,2,1)];
  AB -= control0[TriMesh::TIndex(4,1,2)];
  V   = AB ^ N12;
  N   = V  ^ AB;   // double cross product trick !
  M   = control0[TriMesh::TIndex(4,2,1)];
  M  += control0[TriMesh::TIndex(4,1,2)];
  M  *= 0.5;
  project(control0[TriMesh::TIndex(4,1,1)], M, N, radius);

  radius = 0.5 * l1p ;
  AB  = control1[TriMesh::TIndex(4,2,1)];
  AB -= control1[TriMesh::TIndex(4,1,2)];
  V   = AB ^ N20;
  N   = V  ^ AB;   
  M   = control1[TriMesh::TIndex(4,2,1)];
  M  += control1[TriMesh::TIndex(4,1,2)];
  M  *= 0.5;
  project(control1[TriMesh::TIndex(4,1,1)], M, N, radius);

  radius = 0.5 * l2p ;
  AB  = control2[TriMesh::TIndex(4,2,1)];
  AB -= control2[TriMesh::TIndex(4,1,2)];
  V   = AB ^ N01;
  N   = V  ^ AB;   
  M   = control2[TriMesh::TIndex(4,2,1)];
  M  += control2[TriMesh::TIndex(4,1,2)];
  M  *= 0.5;
  project(control2[TriMesh::TIndex(4,1,1)], M, N, radius);

// -------------------------------------------------
// Nodes surrouding center common control node
// -------------------------------------------------

  tmp =  control0[TriMesh::TIndex(4,0,2)];
  tmp += control0[TriMesh::TIndex(4,1,1)];
  tmp += control1[TriMesh::TIndex(4,1,1)];
  tmp *= (1.0 / 3.0);
  control0[TriMesh::TIndex(4,0,1)] = tmp;
  control1[TriMesh::TIndex(4,1,0)] = tmp;

  tmp =  control1[TriMesh::TIndex(4,0,2)];
  tmp += control1[TriMesh::TIndex(4,1,1)];
  tmp += control2[TriMesh::TIndex(4,1,1)];
  tmp *= (1.0 / 3.0);
  control1[TriMesh::TIndex(4,0,1)] = tmp;
  control2[TriMesh::TIndex(4,1,0)] = tmp;

  tmp =  control2[TriMesh::TIndex(4,0,2)];
  tmp += control2[TriMesh::TIndex(4,1,1)];
  tmp += control0[TriMesh::TIndex(4,1,1)];
  tmp *= (1.0 / 3.0);
  control2[TriMesh::TIndex(4,0,1)] = tmp;
  control0[TriMesh::TIndex(4,1,0)] = tmp;

// -------------------------------------------------
// Center common control node
// -------------------------------------------------

  tmp  = control0[TriMesh::TIndex(4,0,1)];
  tmp += control1[TriMesh::TIndex(4,0,1)];
  tmp += control2[TriMesh::TIndex(4,0,1)];
  tmp *= (1.0 / 3.0);
  control0[TriMesh::TIndex(4,0,0)] = tmp;
  control1[TriMesh::TIndex(4,0,0)] = tmp;
  control2[TriMesh::TIndex(4,0,0)] = tmp;

  _T0->Update(control0);
  _T1->Update(control1);
  _T2->Update(control2);
  
// -------------------------------------------------
// degree 3 is not enough for G1
// -------------------------------------------------

/*
  _T0->DegreeElevation(control0, Control0);
  _T1->DegreeElevation(control1, Control1);
  _T2->DegreeElevation(control2, Control2);
  */

// To be continued ...


}


void SmoothTriangle::RotX(Angle r)
{
  _T0->RotX(r);
  _T1->RotX(r);
  _T2->RotX(r);
}

void SmoothTriangle::RotY(Angle r)
{
  _T0->RotY(r);
  _T1->RotY(r);
  _T2->RotY(r);
}

void SmoothTriangle::RotZ(Angle r)
{
  _T0->RotZ(r);
  _T1->RotZ(r);
  _T2->RotZ(r);
}

void SmoothTriangle::Translate(int tx, int ty, int tz)
{
  _T0->Translate(tx, ty, tz);  
  _T1->Translate(tx, ty, tz);
  _T2->Translate(tx, ty, tz);
}

void SmoothTriangle::Scale(double sx, double sy, double sz)
{
  _T0->Scale(sx, sy, sz);
  _T1->Scale(sx, sy, sz);
  _T2->Scale(sx, sy, sz);
}

void SmoothTriangle::Draw(PolygonEngine *PE)
{
  _T0->Mode() = Mode();
  _T1->Mode() = Mode();
  _T2->Mode() = Mode();
  PE << (*_T0) << (*_T1) << (*_T2);
}

void SmoothTriangle::Lighting(void)
{
  if(!_T0 || !_T1 || !_T2)
    {
       printf("Argh, c'est zarbi !\n");
    }
  _T0->Lighting();
  _T1->Lighting();
  _T2->Lighting();
}

void SmoothTriangle::Shiny(gfloat factor, gfloat lambertian, gfloat specular)
{
  _T0->Shiny(factor, lambertian, specular);
  _T1->Shiny(factor, lambertian, specular);
  _T2->Shiny(factor, lambertian, specular);
}

void SmoothTriangle::Dull()
{
  _T0->Dull();
  _T1->Dull();
  _T2->Dull();
}

SmoothTriangle::~SmoothTriangle(void)
{
  delete _T0;
  delete _T1;
  delete _T2;
}
