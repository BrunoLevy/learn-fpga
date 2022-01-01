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
 * texture.cc
 * 
 */ 


#include "gport.h"
#include "polyeng.h"
#include "texture.h"

int size;

/*
 * read a TGA file and
 * convert it into a texture.
 */ 

char TGA_Signature[] = { 0x00, 0x00, 0x02, 0x00, 0x00, 
                         0x00, 0x00, 0x00, 0x00, 0x00 };
                         

typedef struct
{
unsigned char Signature[10];
unsigned char FirstLine_L;
unsigned char FirstLine_H;
unsigned char Width_L;
unsigned char Width_H;
unsigned char Height_L;
unsigned char Height_H;
unsigned char bpp;
unsigned char mode;
} TGA_Header;

typedef struct
{
unsigned char B;
unsigned char G;
unsigned char R;
} TGA_Pixel;


int LoadTexture(const char* filename, GraphicPort* GP)
{
   // TODO
   /*
   FILE* f = fopen(filename,"r");
   TGA_Header H;
   TGA_Pixel *Line;
   int x,y;
   
   
   if(!f)
      return 0;
   
   fread((char *)&H, sizeof(TGA_Header), 1, f);
   
   if(memcmp(TGA_Signature, H.Signature, (unsigned int)sizeof(TGA_Signature)))
     {
	cerr << "invalid TGA signature" << endl;
	return 0;
     }
   
   if(H.mode != 32)
     {
	cerr << "Sorry, vtga cannot handle this kind of TGA file" << endl;
	return 0;
     }

   if(H.bpp != 24)
     {
	cerr << "Sorry, vtga can handle 24bpp TGA files only" << endl;
	return 0;
     }

   int Width     = (int)H.Width_L     + (((int)H.Width_H)     << 8);
   int Height    = (int)H.Height_L    + (((int)H.Height_H)    << 8);
   int FirstLine = (int)H.FirstLine_L + (((int)H.FirstLine_H) << 8);
   
   size = Width;
   
   GTexel* texture = new GTexel[size * size];
   memset(texture, 0, size*size*sizeof(GTexel));
   Line = new TGA_Pixel[Width];
   
   for(y = 0; (y < Height) && (y < size); y++)
     {
	fread((char *)Line, Width * sizeof(TGA_Pixel), 1, f);
	
	for(x=0; (x < Width) && (x < size); x++)
	   texture[y*size+x] = GTexel(Line[x].R, Line[x].G, Line[x].B, 255); 
   }
   
   delete[] Line;

   GP->TextureBind((uint32 *)texture, size);

   fclose(f);

   return 1;
   */
   return 0;
}


void ToggleTextureMode(PolygonEngine* PE)
{
   static FlagSet flag_save; 
     
   if(PE->Attributes().Get(GA_TEXTURE))
     {
	PE->Attributes().SetAll(flag_save);
	PE->CommitAttributes();
     }
   else
     {
	flag_save = PE->Attributes().GetAll();
//	int zbuff = PE->Attributes().Get(GA_ZBUFFER);
//	int rgb   = PE->Attributes().Get(GA_RGB);
//	PE->Attributes().SetAll(0);
	PE->Attributes().Set(GA_TEXTURE);
//	if(zbuff)
//	  PE->Attributes().Set(GA_ZBUFFER);
//	if(rgb)
//	  PE->Attributes().Set(GA_RGB);  
     }
   
}


