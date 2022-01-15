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
 * locgman.cc
 *
 */

#include "locgman.h"



int  
LocalGeometryManager::WaitEvent(void)
{
  return _graphic_port->WaitEvent();
}

char 
LocalGeometryManager::GetKey(void)
{
  return _graphic_port->GetKey();
}
  
int  
LocalGeometryManager::GetMouse(ScrCoord *x, ScrCoord *y)
{
  int result = _graphic_port->GetMouse(x,y);
  *y = GetHeight() - 1 - *y;
  return result;
}



LocalGeometryManager::LocalGeometryManager(char *name, 
	    ScrCoord width, ScrCoord height, int verbose_level)
{
  
  Verbose(verbose_level);

  _proc_name  = "LocalGeometryManager";
  
  _error_code = GME_OK;

  if((_graphic_port = GraphicPort::Make(name, width, height)))
    _resources.Set(GMR_GPORT);
  else
    {
      _error_code = GME_GPORT;
      return;
    }

  if((_polygon_engine = PolygonEngine::Make(_graphic_port)))
    {
      _resources.Set(GMR_POLYENG);
//      _polygon_engine->Attributes().Set(GA_HCLIP);
      _polygon_engine->CommitAttributes();
    }
  else
    {
      _error_code = GME_POLYENG;
      return;
    }

  _m_mode       = GMM_SINGLE;
  _be_mode      = GBE_NONE;
  _poly_mode    = GPM_FILL;
  _culling_mode = GCM_NONE;

  _stack_modelview_idx = 0;
  _stack_viewport_idx  = 0;

  GetViewport().Set(0, 0, GetWidth()-1, GetHeight()-1);
  GetViewport().Set(0,511);
  _graphic_port->Clip().Set(0, 511);

  GetModelView().LoadIdentity();
  Ortho(0, GetWidth()-1, 0, GetHeight()-1, 5, 16383);

  _polygon_engine->Attributes().Set(PEA_ZCLIP);
  _polygon_engine->CommitAttributes();


  (*this)[MSG_INFO] << "hello, world !!\n";

/*
  cout << "ModelView = " << endl << GetModelView() << endl;
  
  cout << "Project = " << endl << GetProject() << endl;

  cout << "ProjectViewport = " << endl << _project_viewport << endl;
*/

}


LocalGeometryManager::~LocalGeometryManager(void)
{
  if(_resources.Get(GMR_POLYENG))
    delete _polygon_engine;

  if(_resources.Get(GMR_GPORT))
    delete _graphic_port;
}

Flag
LocalGeometryManager::ErrorCode(void)
{
  return _error_code;
}

void
LocalGeometryManager::Begin(gbemode mode)
{
  _be_mode = mode;
  if(_be_mode == GBE_QSTRIP)
    {
      _qstrip_idx = 0;
      _qstrip_nbr = 0;
    }
}

void
LocalGeometryManager::End(void)
{
  switch(_be_mode)
    {
    case GBE_POINTS:
      DoPoints();
      break;

    case GBE_CLOSED_LINE:
      DoClosedLine();
      break;

    case GBE_POLYGON:

      if(_culling_mode)
	{

	  // Compute Z coord of normal

	  GCoord tmp1, tmp2, tmp3, tmp4;
	  GCoord wise;
	  

	  tmp1.lod(_vpool[0].project_position(0));
	  tmp1.sub(_vpool[1].project_position(0));

	  tmp2.lod(_vpool[2].project_position(1));
	  tmp2.sub(_vpool[1].project_position(1));

	  tmp3.lod(_vpool[2].project_position(0));
	  tmp3.sub(_vpool[1].project_position(0));

	  tmp4.lod(_vpool[0].project_position(1));
	  tmp4.sub(_vpool[1].project_position(1));

	  wise.mld(tmp1,tmp2);
	  wise.msb(tmp3,tmp4);

	  if(wise.ge() ^ (_culling_mode == GCM_BACKFACE))
	    goto culled;
	}

      switch(_poly_mode)
	{
	case GPM_VERTICE:
	  DoPoints();
	  break;
	case GPM_EDGES:
	  DoClosedLine();
	  break;
	case GPM_FILL:
	  DoPolygon();
	  break;
	}
      break;

    default:
      break;

    }


 culled:
  _vpool.Reset();
  _polygon_engine->Reset();

  _be_mode = GBE_NONE;
}

void 
LocalGeometryManager::Vertex(gfloat x, gfloat y, gfloat z)
{
  GVertex *v;

  switch(_be_mode)
    {
    case GBE_QSTRIP:
      v = &(_qstrip_pool[_qstrip_idx]);
      _qstrip_idx++;
      _qstrip_idx %= 4;
      _qstrip_nbr++;
      break;
    default:
      v = _vpool.New();
      break;
    }
  
  v->initial_position(0).lod(x);
  v->initial_position(1).lod(y);
  v->initial_position(2).lod(z);
  v->initial_position(3).lod(1);

   if(_m_mode == GMM_SINGLE)
     v->project_position.mld(v->initial_position, GetSingle());
   else
     {
	v->modelview_position.mld(v->initial_position,GetModelView());
	v->project_position.mld(v->modelview_position,_project_viewport);
     }

  if(Attributes().Get(GA_HCLIP))
    {
#ifdef GINT
      v->w = (HCoord)(v->project_position(3).data());
#else
      v->w = (HCoord)(v->project_position(3).data() * (ginternal)(1 << GCOORD_SHIFT));
#endif      
    }
  else
    {
      v->project_position(0).div(v->project_position(3));
      v->project_position(1).div(v->project_position(3));
      v->project_position(2).div(v->project_position(3));
    }

  *(GVertexAttributes *)v = VAttributes();

  v->project_position(0).sto(v->x);
  v->project_position(1).sto(v->y);
  v->project_position(2).sto(v->z);

  switch(_be_mode)
    {
    case GBE_QSTRIP:
      if((_qstrip_nbr >= 4) && ((_qstrip_idx == 0) || (_qstrip_idx == 2)))
	{
	  GVertex *v1, *v2, *v3, *v4;
	  int visible = 1;
	  if(_qstrip_idx == 0)
	    {
	      v1 = &(_qstrip_pool[0]);
	      v2 = &(_qstrip_pool[1]);
	      v3 = &(_qstrip_pool[3]);
	      v4 = &(_qstrip_pool[2]);
	    }
	  else
	    {
	      v1 = &(_qstrip_pool[2]);
	      v2 = &(_qstrip_pool[3]);
	      v3 = &(_qstrip_pool[1]);
	      v4 = &(_qstrip_pool[0]);
	    }

	  if(_culling_mode)
	    {
	      // Compute Z coord of normal

	      GCoord tmp1, tmp2, tmp3, tmp4;
	      GCoord wise;
	  

	      tmp1.lod(v1->project_position(0));
	      tmp1.sub(v2->project_position(0));
	      
	      tmp2.lod(v3->project_position(1));
	      tmp2.sub(v2->project_position(1));

	      tmp3.lod(v3->project_position(0));
	      tmp3.sub(v2->project_position(0));

	      tmp4.lod(v1->project_position(1));
	      tmp4.sub(v2->project_position(1));

	      wise.mld(tmp1,tmp2);
	      wise.msb(tmp3,tmp4);

	      visible = wise.ge() ^ (_culling_mode == GCM_BACKFACE);

	    }

	  if(visible)
	    {
	      _polygon_engine->Reset();
	      _polygon_engine->Push(v1);
	      _polygon_engine->Push(v2);
	      _polygon_engine->Push(v3);
	      _polygon_engine->Push(v4);

	      switch(_poly_mode)
		{
		case GPM_VERTICE:
		  DoPoints();
		  break;
		case GPM_EDGES:
		  DoClosedLine();
		  break;
		case GPM_FILL:
		  DoPolygon();
		  break;
		}
	    }
	}
      break;
    default:
      _polygon_engine->Push(v);
      break;
    }

}


void 
LocalGeometryManager::Vertex(GCoord x, GCoord y, GCoord z)
{
  GVertex *v;

  switch(_be_mode)
    {
    case GBE_QSTRIP:
      v = &(_qstrip_pool[_qstrip_idx]);
      _qstrip_idx++;
      _qstrip_idx %= 4;
      _qstrip_nbr++;
      break;
    default:
      v = _vpool.New();
      break;
    }
  
  v->initial_position(0) = x;
  v->initial_position(1) = y;
  v->initial_position(2) = z;
  v->initial_position(3).lod(1);

   
  if(_m_mode == GMM_SINGLE)
     v->project_position.mld(v->initial_position, GetSingle());
   else
     {
	v->modelview_position.mld(v->initial_position,GetModelView());
	v->project_position.mld(v->modelview_position,_project_viewport);
     }

  if(Attributes().Get(GA_HCLIP))
    {
#ifdef GINT
      v->w = (HCoord)(v->project_position(3).data());
#else
      v->w = (HCoord)(v->project_position(3).data() * (ginternal)(1 << GCOORD_SHIFT));
#endif      
    }
  else
    {
      v->project_position(0).div(v->project_position(3));
      v->project_position(1).div(v->project_position(3));
      v->project_position(2).div(v->project_position(3));
    }

  *(GVertexAttributes *)v = VAttributes();

  v->project_position(0).sto(v->x);
  v->project_position(1).sto(v->y);
  v->project_position(2).sto(v->z);

  switch(_be_mode)
    {
    case GBE_QSTRIP:
      if((_qstrip_nbr >= 4) && ((_qstrip_idx == 0) || (_qstrip_idx == 2)))
	{
	  GVertex *v1, *v2, *v3, *v4;
	  int visible = 1;
	  if(_qstrip_idx == 0)
	    {
	      v1 = &(_qstrip_pool[0]);
	      v2 = &(_qstrip_pool[1]);
	      v3 = &(_qstrip_pool[3]);
	      v4 = &(_qstrip_pool[2]);
	    }
	  else
	    {
	      v1 = &(_qstrip_pool[2]);
	      v2 = &(_qstrip_pool[3]);
	      v3 = &(_qstrip_pool[1]);
	      v4 = &(_qstrip_pool[0]);
	    }

	  if(_culling_mode)
	    {
	      // Compute Z coord of normal

	      GCoord tmp1, tmp2, tmp3, tmp4;
	      GCoord wise;
	  

	      tmp1.lod(v1->project_position(0));
	      tmp1.sub(v2->project_position(0));
	      
	      tmp2.lod(v3->project_position(1));
	      tmp2.sub(v2->project_position(1));

	      tmp3.lod(v3->project_position(0));
	      tmp3.sub(v2->project_position(0));

	      tmp4.lod(v1->project_position(1));
	      tmp4.sub(v2->project_position(1));

	      wise.mld(tmp1,tmp2);
	      wise.msb(tmp3,tmp4);

	      visible = wise.ge() ^ (_culling_mode == GCM_BACKFACE);

	    }

	  if(visible)
	    {
	      _polygon_engine->Reset();
	      _polygon_engine->Push(v1);
	      _polygon_engine->Push(v2);
	      _polygon_engine->Push(v3);
	      _polygon_engine->Push(v4);

	      switch(_poly_mode)
		{
		case GPM_VERTICE:
		  DoPoints();
		  break;
		case GPM_EDGES:
		  DoClosedLine();
		  break;
		case GPM_FILL:
		  DoPolygon();
		  break;
		}
	    }
	}
      break;
    default:
      _polygon_engine->Push(v);
      break;
    }

}

void 
LocalGeometryManager::Normal(gfloat x, gfloat y, gfloat z)
{
}
 
void 
LocalGeometryManager::Color(gfloat r, gfloat g, gfloat b)
{
  VAttributes().r = (ColorComponent)r;
  VAttributes().g = (ColorComponent)g;
  VAttributes().b = (ColorComponent)b;
}

void 
LocalGeometryManager::Color(gint r, gint g, gint b)
{
  VAttributes().r = (ColorComponent)r;
  VAttributes().g = (ColorComponent)g;
  VAttributes().b = (ColorComponent)b;
}

void 
LocalGeometryManager::Color(gfloat c)
{
  VAttributes().c = (ColorCode)(c * gfloat(1 << D_SHIFT));
}

void
LocalGeometryManager::Color(gint   c)
{
  VAttributes().c = (ColorCode)(c << D_SHIFT);
}

void 
LocalGeometryManager::CommitAttributes(void)
{
  Flags changed;

  changed.SetAll(_last_attributes.GetAll() ^ Attributes().GetAll());

  if(changed.Get(GA_RGB))
    {
      if(Attributes().Get(GA_RGB))
	{
	  _graphic_port->RGBMode();
	  _polygon_engine->RGBMode();
	}
      else
	{
	  _graphic_port->ColormapMode();
	  _polygon_engine->ColormapMode();
	}
    }

  if(changed.Get(GA_GOURAUD))
    _polygon_engine->Gouraud(Attributes().Get(GA_GOURAUD));

  if(changed.Get(GA_DITHER))
    _polygon_engine->Dither(Attributes().Get(GA_DITHER));

  if(changed.Get(GA_ZBUFFER))
    {
      _graphic_port->ZBuffer(Attributes().Get(GA_ZBUFFER));
      _polygon_engine->ZBuffer(Attributes().Get(GA_ZBUFFER));
    }
}


void 
LocalGeometryManager::Clear()
{
  _graphic_port->Clear(BLACK);
}
 
void 
LocalGeometryManager::ZClear(void)
{
  _graphic_port->ZClear();
}
 
void 
LocalGeometryManager::ZClear(ZCoord z)
{
  _graphic_port->ZClear(z);
}

int  
LocalGeometryManager::SingleBuffer(void)
{
  return _graphic_port->SingleBuffer();
}

int  
LocalGeometryManager::DoubleBuffer(void)
{
  return _graphic_port->DoubleBuffer();
}

int  
LocalGeometryManager::SwapBuffers(void)
{
  return _graphic_port->SwapBuffers();
}

void 
LocalGeometryManager::MapColor(const ColorIndex i, 
			       const ColorComponent r, 
			       const ColorComponent g, 
			       const ColorComponent b )
{
  _graphic_port->MapColor(i,r,g,b);
}

ScrCoord
LocalGeometryManager::Width(void)
{
  return GetWidth();
}

ScrCoord
LocalGeometryManager::Height(void)
{
  return GetHeight();
}


void
LocalGeometryManager::MatrixMode(gmmode mode)
{
  _m_mode = mode;
}

void
LocalGeometryManager::PushMatrix(void)
{
#ifdef EBUG
  assert(_stack_modelview_idx < (ATTRIB_STACK_SZ - 1));
#endif
   
  _stack_modelview_idx++;
  _stack_modelview[_stack_modelview_idx] = 
    _stack_modelview[_stack_modelview_idx - 1];
   
   if(_m_mode == GMM_SINGLE)
     {
#ifdef EBUG
	assert(_stack_single_idx < (ATTRIB_STACK_SZ - 1));
#endif	
	_stack_single_idx++;
	_stack_single[_stack_single_idx] = 
  	    _stack_single[_stack_single_idx - 1];
     }
}

void
LocalGeometryManager::PopMatrix(void)
{
#ifdef EBUG
  assert(_stack_modelview_idx > 0);
#endif
  _stack_modelview_idx--;
   
   if(_m_mode == GMM_SINGLE)
     {
#ifdef EBUG
	assert(_stack_single_idx > 0);	
#endif	
	_stack_single_idx--;
     }
}

void
LocalGeometryManager::Identity(void)
{
  switch(_m_mode)
    {
    case GMM_SINGLE:
    case GMM_MODELVIEW:
      GetModelView().LoadIdentity();
      break;
    case GMM_PROJECT:
      GetProject().LoadIdentity();
      CommitViewport();
      break;
    case GMM_TEXTURE:
      GetTexture().LoadIdentity();
      break;
    }
   CommitSingle();
}

void 
LocalGeometryManager::Perspective(gAngle _fov, gfloat _aspect, 
			     gfloat _near, gfloat _far)
{
   GetProject().LoadPerspective(_fov, _aspect, _near, _far);
   CommitViewport();
   CommitSingle();   
}

void 
LocalGeometryManager::Ortho(gfloat _left, gfloat _right, gfloat _bottom, 
		       gfloat _top, gfloat _near, gfloat _far)
{
   GetProject().LoadOrtho(_left, _right, _bottom, _top, _near, _far);
   CommitViewport();
   CommitSingle();   
}


void 
LocalGeometryManager::PolarView(gfloat dist, gAngle azim, 
			   gAngle inc, gAngle twist)
{
  switch(_m_mode)
    {
    case GMM_SINGLE:
    case GMM_MODELVIEW:
      GetModelView().PolarView(dist, azim, inc, twist);
      break;
    case GMM_PROJECT:
      GetProject().PolarView(dist, azim, inc, twist);
      CommitViewport();
      break;
    case GMM_TEXTURE:
      GetTexture().PolarView(dist, azim, inc, twist);
      break;
    }
   CommitSingle();   
}

void 
LocalGeometryManager::LookAt(gfloat vx, gfloat vy, gfloat vz,
			     gfloat px, gfloat py, gfloat pz)
{
  switch(_m_mode)
    {
    case GMM_SINGLE:
    case GMM_MODELVIEW:
      GetModelView().LookAt(vx, vy, vz, px, py, pz);
      break;
    case GMM_PROJECT:
      GetProject().LookAt(vx, vy, vz, px, py, pz);
      CommitViewport();
      break;
    case GMM_TEXTURE:
      GetTexture().LookAt(vx, vy, vz, px, py, pz);
      break;
    }
   CommitSingle();   
}

void 
LocalGeometryManager::LookAt(gfloat vx, gfloat vy, gfloat vz,
			     gfloat px, gfloat py, gfloat pz, 
			     gAngle twist)
{
  switch(_m_mode)
    {
    case GMM_SINGLE:
    case GMM_MODELVIEW:
      GetModelView().LookAt(vx, vy, vz, px, py, pz, twist);
      break;
    case GMM_PROJECT:
      GetProject().LookAt(vx, vy, vz, px, py, pz, twist);
      CommitViewport();
      break;
    case GMM_TEXTURE:
      GetTexture().LookAt(vx, vy, vz, px, py, pz, twist);
      break;
    }
   CommitSingle();   
}



void 
LocalGeometryManager::Translate(gfloat x, gfloat y, gfloat z)
{
  switch(_m_mode)
    {
    case GMM_SINGLE:
    case GMM_MODELVIEW:
      GetModelView().Translate(x,y,z);
      break;
    case GMM_PROJECT:
      GetProject().Translate(x,y,z);
      CommitViewport();
      break;
    case GMM_TEXTURE:
      GetTexture().Translate(x,y,z);
      break;
    }
   CommitSingle();   
}
 
void 
LocalGeometryManager::Rotate(gAngle r, char axis)
{
  switch(_m_mode)
    {
    case GMM_SINGLE:
    case GMM_MODELVIEW:
      GetModelView().Rotate(r,axis);
      break;
    case GMM_PROJECT:
      GetProject().Rotate(r,axis);
      CommitViewport();
      break;
    case GMM_TEXTURE:
      GetTexture().Rotate(r,axis);
      break;
    }
   CommitSingle();   
}

void 
LocalGeometryManager::Scale(gfloat sx, gfloat sy, gfloat sz)
{
  switch(_m_mode)
    {
    case GMM_SINGLE:
    case GMM_MODELVIEW:
      GetModelView().Scale(sx, sy, sz);
      break;
    case GMM_PROJECT:
      GetProject().Scale(sx, sy, sz);
      CommitViewport();
      break;
    case GMM_TEXTURE:
      GetTexture().Scale(sx, sy, sz);
      break;
    }
   CommitSingle();   
}

void 
LocalGeometryManager::LoadMatrix(GMatrix& M)
{
  switch(_m_mode)
    {
    case GMM_SINGLE:
    case GMM_MODELVIEW:
      GetModelView() = M;
      break;
    case GMM_PROJECT:
      GetProject() = M;
      CommitViewport();
      break;
    case GMM_TEXTURE:
      GetTexture() = M;
      break;
    }
   CommitSingle();   
}

void 
LocalGeometryManager::MultMatrix(GMatrix& M)
{
  switch(_m_mode)
    {
    case GMM_SINGLE:
    case GMM_MODELVIEW:
      GetModelView().mul(M);
      break;
    case GMM_PROJECT:
      GetProject().mul(M);
      CommitViewport();
      break;
    case GMM_TEXTURE:
      GetTexture().mul(M);
      break;
    }
   CommitSingle();   
}

void 
LocalGeometryManager::GetMatrix(GMatrix&  M)
{
  switch(_m_mode)
    {
    case GMM_SINGLE:
    case GMM_MODELVIEW:
      M = GetModelView();
      break;
    case GMM_PROJECT:
      M = GetProject();
      CommitViewport();
      break;
    case GMM_TEXTURE:
      M = GetTexture();
      break;
    }
   CommitSingle();   
}


void 
LocalGeometryManager::Viewport(ScrCoord left, ScrCoord right, 
			       ScrCoord bottom, ScrCoord top)
{
   GetViewport().Set(left, GetHeight() - 1 - top, 
		     right, GetHeight() - 1 - bottom);
   ScreenMask(left, right, bottom, top);
   CommitViewport();
   CommitSingle();   
}

void 
LocalGeometryManager::PushViewport(void)
{
#ifdef EBUG
  assert(_stack_viewport_idx < (ATTRIB_STACK_SZ - 1));
#endif
  _stack_viewport_idx++;
  _stack_viewport[_stack_viewport_idx] = 
    _stack_viewport[_stack_viewport_idx - 1];
}
 
void 
LocalGeometryManager::PopViewport(void)
{
#ifdef EBUG
  assert(_stack_viewport_idx > 0);
#endif
  _stack_viewport_idx--;
  CommitViewport();
  CommitSingle();   
}

void 
LocalGeometryManager::ScreenMask(ScrCoord left, ScrCoord right, 
				 ScrCoord bottom, ScrCoord top)
{
  _graphic_port->Clip().Set(left,  GetHeight() - top - 1, 
			    right, GetHeight() - bottom - 1);
}

void 
LocalGeometryManager::SetDepth(ZCoord _near, ZCoord _far)
{
  GetViewport().Set(_near, _far);
  CommitViewport();
  CommitSingle();   
  _graphic_port->Clip().Set(_near, _far);
}


void 
LocalGeometryManager::CommitViewport(void)
{
  GMatrix tmp;

  tmp.LoadZero();

  tmp(0,0).lod(0.5*(GetViewport()._x2 - GetViewport()._x1));
  tmp(1,1).lod(0.5*(GetViewport()._y1 - GetViewport()._y2));
  tmp(2,2).lod(0.5*(GetViewport()._z2 - GetViewport()._z1));
  
  tmp(3,0).lod(GetViewport()._x1 + 
	       0.5*(GetViewport()._x2 - GetViewport()._x1));

  // y coordinates are downwards oriented ...

  tmp(3,1).lod(GetViewport()._y2 + 
	       0.5*(GetViewport()._y1 - GetViewport()._y2));

  tmp(3,2).lod(GetViewport()._z1 + 
	       0.5*(GetViewport()._z2 - GetViewport()._z1));

  tmp(3,3).lod(1);

  _project_viewport.mld(_project,tmp);

/*
  cout << "tmp (Viewport transform) = " << endl << tmp << endl;

  cout << "ModelView = " << endl << GetModelView() << endl;
  
  cout << "Project = " << endl << GetProject() << endl;

  cout << "ProjectViewport = " << endl << _project_viewport << endl;
*/

}

void 
LocalGeometryManager::PolygonMode(gpmode mode)
{
  _poly_mode = mode;
}

void 
LocalGeometryManager::CullingMode(gcmode mode)
{
  _culling_mode = mode;
}
