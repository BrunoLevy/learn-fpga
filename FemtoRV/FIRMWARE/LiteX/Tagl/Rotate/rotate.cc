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
 * rotate.cc
 *
 * This program demonstrates TAGL polygon drawing and 
 * shading abilities. 
 *
 */


#include <stdlib.h>
#include "gport.h"
#include "LiteXgport.h"
#include "polyeng.h"
#include "mesh.h"
#include "trimesh.h"
#include "bezier.h"
#include "smtri.h"
#include "smmesh.h"
#include <time.h>
#include "texture.h"
#include "cmdline.h"
#include <libfatfs/ff.h>

extern "C" {
   void init_gport_X() ;
   void init_peng_32x();
   void init_peng_x32();
   void init_peng_32xi();
   void init_peng_24();   
}


void* operator new(size_t sz) 
{
   return malloc(sz);
}

void* operator new[](size_t sz) 
{
   return malloc(sz);
}

void operator delete(void* p) 
{
   free(p);
}


void operator delete[](void* p)
{
   free(p);
}

extern "C" void __cxa_pure_virtual() { while (1); }


void init_pengs() 
{
//   init_gport_X() ;
//   init_peng_32x() ;
   init_peng_x32() ;
//   init_peng_32xi() ; 
//   init_peng_24() ;
}


static const int verbose = 1;

GraphicPort   *GP;
PolygonEngine *PE;
Mesh          *m;

int do_lighting   = 1;
int do_env_map    = 0;
int do_tex_map    = 0;
int do_tex_map_10 = 0;

const int rrx = 4;
const int rry = 4;
const int rrz = 4;

const int rlrx = 4;
const int rlry = 4;
const int rlrz = 4;

int rx = 0;
int ry = 0;
int rz = 0;

int rlx = 0;
int rly = 0;
int rlz = 0;

int rlight = 0;
int clip_plane = 300;


char*   geometry_filename = NULL;
char*   color_filename    = NULL;
char*   texture_filename  = NULL;
char*   command_string    = NULL;
int     camera_width      = 320;
int     camera_height     = 200;
int     help_flag  = 0;
int     texture_ok = 0;
int     autorot_treshold = 1;
const char*   window_title = "TAGL 3D object viewer";

CmdLineArg args[] = 
{
   "-geom",    CMD_LINE_STR, 1, &geometry_filename, 0,
   "-col",     CMD_LINE_STR, 0, &color_filename,    0,
   "-tex",     CMD_LINE_STR, 0, &texture_filename,  0,
   "-exec",    CMD_LINE_STR, 0, &command_string,    0,
   "-h",       CMD_LINE_FLG, 0, &help_flag,         0,
   "-width",   CMD_LINE_INT, 0, &camera_width,      1,
   "-height",  CMD_LINE_INT, 0, &camera_height,     1,
   "-autorot", CMD_LINE_INT, 0, &autorot_treshold,  1,
   "-title",   CMD_LINE_STR, 0, &window_title,      1,
   NULL, 0, 0, 0, 0
};


#define ABS(x) ((x) > 0 ? (x) : -(x))

inline void ColorToggle(Mesh *m)
{
  static int color = 0;

  int i;

  if(!m->Resources().Get(MR_COLORS))
     return;

  if(color)
    {
      GP->ColormapMode();
      PE->ColormapMode();

      for(i=0; i<64; i++)
	GP->MapColor(i, i << 2, i << 2, i << 2);

      m->Mode().Reset(MF_COLOR);
      color = 0;
    }
  else
    {
      GP->RGBMode();
      PE->RGBMode();
      m->Mode().Set(MF_COLOR);
      color = 1;
    }
}

inline void Toggle(Mesh *mesh, Flag f)
{
  if(mesh->Mode().Get(f))
    mesh->Mode().Reset(f);
  else
    {
      if(f == GF_SPECULAR)
	mesh->Shiny(30.0, 0.8, 1.4);
      mesh->Mode().Set(f);
    }
}

inline void Toggle(PolygonEngine *pe, Flag f)
{
  if(pe->Attributes().Get(f))
    pe->Attributes().Reset(f);
  else
    pe->Attributes().Set(f);
  pe->CommitAttributes();
}

inline void Toggle(int &flag)
{
  flag = flag ? 0 : 1;
}

void DoCommand(char q)
{
  static gfloat gamma = 1.0;
   
  switch(q)
    {
    case '+':
      m->ZoomIn();
      break;
       
    case '-':
      m->ZoomOut();
      break;
       
    case 'w':
      Toggle(m, MF_SMOOTH);
      break;
       
    case 'n':
      m->InvertNormals();
      break;
       
    case 'd':
      Toggle(PE,GA_DITHER);
      break;
       
    case 'z':
      Toggle(m, MF_CONVEX);
      break;
       
    case 'c':
      Toggle(m, MF_CLOSED);
      break;
       
    case 'a':
      Toggle(m, MF_WIREFRAME);
      break;
       
    case 'l':
      Toggle(do_lighting);
      break;
       
    case 'r':
      m->ResetColors();
      break;
       
    case 'm':
      Toggle(rlight);
      break;
       
    case 'C':   
    case ' ':
      ColorToggle(m);
      break;
       
    case 's':
      Toggle(m, GF_SPECULAR);
      break;
       
    case 'g':
      gamma += 0.1;
      if(gamma > 3.0)
	gamma = 3.0;
      GraphicObject::GammaRamp(gamma);
      break;
       
    case 'h':
      gamma -= 0.1;
      if(gamma < 0.1)
	gamma = 0.1;
      GraphicObject::GammaRamp(gamma);
      break;

    case 'Z':
      Toggle(PE,PEA_ZCLIP);
      break;

    case '0':
      if(rlight)
	rlx = rly = rlz = 0;
      else
	rx = ry = rz = 0;
      break;

    case 'o':
      clip_plane += 10;
      break;
      
    case 'p':
      clip_plane -= 10;
      break;

    case '1':
      if(rlight)
	rlx += rlrx;
      else
	rx += rrx;
      break;

    case '2':
      if(rlight)
	rly += rlry;
      else
	ry += rry;
      break;

    case '3':
      if(rlight)
	rlz += rlrz;
      else
	rz += rrz;
      break;

    case '4':
      if(rlight)
	rlx = 0;
      else
	rx = 0;
      break;

    case '5':
      if(rlight)
	rly = 0;
      else
	ry = 0;
      break;

    case '6':
      if(rlight)
	rlz = 0;
      else
	rz = 0;
      break;

    case '7':
      if(rlight)
	rlx -= rlrx;
      else
	rx -= rrx;
      break;

    case '8':
      if(rlight)
	rly -= rlry;
      else
	ry -= rry;
      break;

    case '9':
      if(rlight)
	rlz -= rlrz;
      else
	rz -= rrz;
      break;
      
    case '[':
      GP->SingleBuffer();
      break;

    case ']':
      GP->DoubleBuffer();
      break;

    case 't':
       if(texture_ok)
       	  ToggleTextureMode(PE);
       break;
     
    case 'T':
       if(texture_ok)       
       	  do_env_map = !do_env_map;
      break;
       
     case 'u':
       if(texture_ok)       
       	  do_tex_map = !do_tex_map;
       break;
       
     case 'U':
       if(texture_ok)       
       	  do_tex_map_10 = !do_tex_map_10;
       break;
       
       
    default:
      break;
    }
}

int main(int argc, char *argv[])
{
  FATFS fs;
  GraphicPort::Register(LiteXGraphicPort::Make,GP_VC_NORMAL); 
  init_pengs() ;
   
  int i;
  time_t elapsed = 0;
  int frames  = 0;

  if(!CmdLineParse(argc, argv, args))
     {
	printf("%s: invalid command line",argv[0]); 
	CmdLineUsage(argv[0], args);
	exit(-1);
     }
   
  if(help_flag)
     {
	CmdLineUsage(argv[0], args);
     }
   
  GP = GraphicPort::Make(window_title, camera_width, camera_height);

  if(!GP)
    {
       printf("cannot open graphic port\n");
       exit(-1);
    }

  PE = PolygonEngine::Make(GP);

  if(!PE)
    {
      delete GP;
      printf("cannot create polygon engine\n");
      exit(-1);
    }

  PE->ColormapMode();

  for(i=0; i<64; i++)
    GP->MapColor(i, i << 2, i << 2, i << 2);

  GP->ZBuffer(1);

   if(f_mount(&fs,"",1) != FR_OK) {
      printf("Could not mount filesystem\n");
      return -1;
   }    
   
   if(verbose)
     printf("Texture setup ...\n");
   if(texture_filename)
     {
	if(!LoadTexture(texture_filename,GP))
	  printf("%s: Could not read texture %s\n",argv[0],texture_filename);
	else
	   texture_ok = 1;
     }
   else
     {
	printf("%s: No texture specified, trying \'texture.tga\'\n",argv[0]);
	texture_ok = LoadTexture("texture.tga",GP);
     }

   m = new Mesh;

   m->load_geometry(geometry_filename);

   if(m->ErrorCode())
     {
	delete PE;
	delete GP;
	printf("%s: geometry file: error code #%d\n",argv[0],m->ErrorCode());
	exit(-1);
     }

   
   if(color_filename)
     {
	m->load_colors(color_filename);
	if(m->ErrorCode())
	  {
	     delete PE;
	     delete GP;
	     printf("color file: error code #%d\n",m->ErrorCode());
	     exit(-1);
	  }
	else
	  {
	     if(verbose)
	       printf("blending object colors ...\n");
	     m->Blend();
	     if(verbose)
	       printf("blending completed.\n");
	  }
     }
   else
      m->White();  
   
   if(verbose)
       printf("smoothing object ...\n");
   
   m->Smooth();
   m->Mode().Set(MF_CLOSED);

       
   if(verbose)
      printf("object processed, ready to render.\n");


  m->TextureMap('x',1.0);
   
   
  char* command_ptr = command_string; 
   
  elapsed = 0; // time(NULL);

  char q = 0;

  int oldx = 0, oldy = 0;
  int btn;
  int dx, dy;
  int translating    = 0;
  int rotating       = 0;
  int rotating_light = 0;
  int running = 1;

  while(running)
    {
      int mx, my;
      dx = mx - oldx;
      dy = my - oldy;
      oldx = mx;
      oldy = my;

       
      if(q == 'q') 
       	  running = 0;
       
      GP->WaitEvent();
      q   = (command_ptr && *command_ptr) ? *command_ptr++ : GP->GetKey();
      btn = GP->GetMouse(&mx, &my);

      DoCommand(q);

      if(btn == 1)
	{
	  if(rotating)
	     {
		m->Rotate(dy >> 2,dx >> 2,0);
		if(autorot_treshold)
		  {
		     if((ABS(dx) > autorot_treshold) || 
			(ABS(dy) > autorot_treshold))
		       {
			  rx = dy >> 2;
			  ry = dx >> 2;
		       }
		     else
		       {
			  rx = 0;
			  ry = 0;
		       }
		  }
	     }
	  else
	    rotating = 1;
	}
      else
	rotating = 0;
      
      if((btn == 2) || (btn == (1 | 4)))
	{
	  if(translating)
	    m->Translate(dx << 4, dy << 4, 0);
	  else
	    translating = 1;
	}
      else
	translating = 0;

      if(btn == (1 | 2 | 4))
	{
	  if(rotating_light)
	    m->LightDirection().Rotate((dy) >> 2,(dx) >> 2,0);
	  else
	    rotating_light = 1;
	}
      else
	rotating_light = 0;
  

      if(btn == 4)
	{
	  if(dx > 0)
	    m->ZoomIn();
	  if(dx < 0)
	    m->ZoomOut();
	}

      if(rx || ry || rz)
	m->Rotate(rx, ry, rz);

      if(rlx || rly || rlz)
	m->LightDirection().Rotate(rlx, rly, rlz);

      if(do_lighting)
	m->Lighting();

      if(do_env_map)
       	m->EnvironMap();
       
      if(do_tex_map)
	 {
	    do_tex_map_10 = 0;
	    do_env_map = 0;
	    m->TextureMap('x', 1.0);
	 }       
       
      if(do_tex_map_10)
	 {
	    do_tex_map = 0;
	    do_env_map = 0;
	    m->TextureMap('x', 4.0);
	 }
       
      m->Setup(PE);
      
      GP->Clip().Set(10,10,GP->Width() - 10, GP->Height() - 10);
      GP->Clip().Set(clip_plane,1024);

      PE << *m;
      GP->SwapBuffers();
      frames++;
      printf("frame: %d\n",frames);
    }


//  elapsed = time(NULL) - elapsed;

  delete PE;
  delete GP;

  if(elapsed) 
     printf(" elapsed: %lld frames: %d fps: %f\n",elapsed,frames,(double)frames/(double)elapsed);

  return 0;
}



