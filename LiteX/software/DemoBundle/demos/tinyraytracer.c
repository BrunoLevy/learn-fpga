/* A port of Dmitry Sokolov's tiny raytracer to C and to FemtoRV32 */
/* Displays on the small OLED display and/or HDMI                  */
/* Bruno Levy, 2021                                                */
/* Original tinyraytracer: https://github.com/ssloy/tinyraytracer  */

#include "demos.h"
#include "lite_oled.h"
#include "lite_fb.h"

#include <generated/soc.h>
#include <libbase/uart.h>
#include <libbase/console.h>

#include <stdio.h>
#include <math.h>

/*******************************************************************/

#ifdef min
#undef min
#endif

#ifdef max
#undef max
#endif


typedef int BOOL;

static inline float max(float x, float y) { return x>y?x:y; }
static inline float min(float x, float y) { return x<y?x:y; }

static int benchmark = 0;
static BOOL with_fb = 0;

/*******************************************************************/

// If you want to adapt tinyraytracer to your own platform, there are
// mostly two macros and two functions to write:
//   graphics_width
//   graphics_height
//   graphics_init()
//   graphics_set_pixel()
//
// You can also write the following functions (or leave them empty if
// you do not need them):
//   graphics_terminate()
//   stats_begin_frame()
//   stats_begin_pixel()
//   stats_end_pixel()
//   stats_end_frame()


// Size of the screen
// Replace with your own variables or values
int graphics_width  = OLED_WIDTH;
int graphics_height = OLED_HEIGHT; 

// Replace with your own stuff to initialize graphics
static inline void graphics_init(void) {
   oled_init();
   if(benchmark) {
       with_fb = 0;
       graphics_width  = OLED_WIDTH;
       graphics_height = OLED_HEIGHT; 
   } else {
       with_fb = fb_init();
   }
   if(with_fb) {
      graphics_width  = FB_WIDTH;
      graphics_height = FB_HEIGHT;
   }
}

// Replace with your own stuff to terminate graphics or leave empty
static inline void graphics_terminate(void) {
}


// Replace with your own code.
static void graphics_set_pixel(int x, int y, float r, float g, float b) {
   r = max(0.0f, min(1.0f, r));
   g = max(0.0f, min(1.0f, g));
   b = max(0.0f, min(1.0f, b));

   uint8_t R = (uint8_t)(255.0f * r);
   uint8_t G = (uint8_t)(255.0f * g);
   uint8_t B = (uint8_t)(255.0f * b);

   if(with_fb) {
      fb_setpixel_RGB(x,y,R,G,B);
      return;
   } 
     
   oled_setpixel_RGB(x,y,R,G,B);

   if(!benchmark) {
     // See: https://stackoverflow.com/questions/4842424/
     //          list-of-ansi-color-escape-sequences   
     printf("\033[48;2;%d;%d;%dm ",R,G,B);
     if(x==OLED_WIDTH-1) {
       puts("\033[48;2;0;0;0m");
     }
   }
}

uint32_t frame_Kticks; // clock Kilo-ticks taken to render frame
uint32_t pixel_ticks;  // clock ticks taken to render pixel

// Begins statistics collection for current frame.
// Leave emtpy if not needed.
static inline void stats_begin_frame(void) {
  frame_Kticks = 0;
  printf(
      "Running on %s %d MHz\n",
      CONFIG_CPU_HUMAN_NAME, 
      CONFIG_CLOCK_FREQUENCY / 1000000
  );
}

// Begins statistics collection for current pixel
// Leave emtpy if not needed.
// There are these two levels because on some
// femtorv32 cores (quark, tachyon), the clock tick counter does not
// have sufficient bits and will wrap during the time taken by
// rendering a frame (up to several minutes).
static inline void stats_begin_pixel(void) {
   // Init timer.
   // (copied from LiTex libbase/memtest.c,
   //  I do not fully understand what I'm doing)
   timer0_en_write(0);
   timer0_reload_write(0);
   timer0_load_write(0xffffffff);
   timer0_en_write(1);
   // Start timer
   timer0_update_value_write(1);
   pixel_ticks = timer0_value_read();
}

// Ends statistics collection for current pixel
// Leave emtpy if not needed.
static inline void stats_end_pixel(void) {
  // Stop timer
  // (copied from LiTex libbase/memtest.c,
  //  I do not fully understand what I'm doing)
  timer0_update_value_write(1);
  pixel_ticks -= timer0_value_read();
  frame_Kticks += (pixel_ticks/1000);
}

// Ends statistics collection for current frame
// and displays result.
// Leave emtpy if not needed.
static inline void stats_end_frame(void) {
  // Not using floats because my own version of printf()
  // in libfemtorv does not support them.
  uint32_t milliseconds = (uint32_t)(frame_Kticks / (CONFIG_CLOCK_FREQUENCY / 1000000));
  uint32_t seconds = milliseconds / 1000;
  uint32_t minutes = seconds / 60;
  uint32_t rem_seconds = seconds % 60;
  uint32_t MHz = CONFIG_CLOCK_FREQUENCY / 1000000;
  uint32_t pixels = graphics_width*graphics_height;
  float raystones = 1000000.0 * ((float)pixels / (float)(milliseconds*MHz));
  
  printf(
      "Elapsed time=%02d:%02d (%d milliseconds)\n", 
      (int)minutes, (int)rem_seconds, (int)milliseconds
  );

  printf(
     "%s@%ldMHz: %ld.%ld raystones (pixels/s/MHz)\n",
     CONFIG_CPU_HUMAN_NAME,  MHz,
     (uint32_t)raystones / 1000, (uint32_t)raystones % 1000
  );
    
  if(!benchmark) {
    puts("  Note: \"graphic\" tty output active (takes time)");    
    puts("  to do benchmarking, use \'raystones\' instead");
  }
}

// Normally you will not need to modify anything beyond that point.
/*******************************************************************/

typedef struct { float x,y,z; }   vec3;
typedef struct { float x,y,z,w; } vec4;

static inline vec3 make_vec3(float x, float y, float z) {
  vec3 V;
  V.x = x; V.y = y; V.z = z;
  return V;
}

static inline vec4 make_vec4(float x, float y, float z, float w) {
  vec4 V;
  V.x = x; V.y = y; V.z = z; V.w = w;
  return V;
}

static inline vec3 vec3_neg(vec3 V) {
  return make_vec3(-V.x, -V.y, -V.z);
}

static inline vec3 vec3_add(vec3 U, vec3 V) {
  return make_vec3(U.x+V.x, U.y+V.y, U.z+V.z);
}

static inline vec3 vec3_sub(vec3 U, vec3 V) {
  return make_vec3(U.x-V.x, U.y-V.y, U.z-V.z);
}

static inline float vec3_dot(vec3 U, vec3 V) {
  return U.x*V.x+U.y*V.y+U.z*V.z;
}

static inline vec3 vec3_scale(float s, vec3 U) {
  return make_vec3(s*U.x, s*U.y, s*U.z);
}

static inline float vec3_length(vec3 U) {
  return sqrtf(U.x*U.x+U.y*U.y+U.z*U.z);
}

static inline vec3 vec3_normalize(vec3 U) {
  return vec3_scale(1.0f/vec3_length(U),U);
}

/*************************************************************************/

typedef struct Light {
    vec3 position;
    float intensity;
} Light;

static Light make_Light(vec3 position, float intensity) {
  Light L;
  L.position = position;
  L.intensity = intensity;
  return L;
}

/*************************************************************************/

typedef struct {
    float refractive_index;
    vec4  albedo;
    vec3  diffuse_color;
    float specular_exponent;
} Material;

static Material make_Material(float r, vec4 a, vec3 color, float spec) {
  Material M;
  M.refractive_index = r;
  M.albedo = a;
  M.diffuse_color = color;
  M.specular_exponent = spec;
  return M;
}

static Material make_Material_default(void) {
  Material M;
  M.refractive_index = 1;
  M.albedo = make_vec4(1,0,0,0);
  M.diffuse_color = make_vec3(0,0,0);
  M.specular_exponent = 0;
  return M;
}

/*************************************************************************/

typedef struct {
  vec3 center;
  float radius;
  Material material;
} Sphere;

static Sphere make_Sphere(vec3 c, float r, Material M) {
  Sphere S;
  S.center = c;
  S.radius = r;
  S.material = M;
  return S;
}

static BOOL Sphere_ray_intersect(Sphere* S, vec3 orig, vec3 dir, float* t0) {
  vec3 L = vec3_sub(S->center, orig);
  float tca = vec3_dot(L,dir);
  float d2 = vec3_dot(L,L) - tca*tca;
  float r2 = S->radius*S->radius;
  if (d2 > r2) return 0;
  float thc = sqrtf(r2 - d2);
  *t0       = tca - thc;
  float t1 = tca + thc;
  if (*t0 < 0) *t0 = t1;
  if (*t0 < 0) return 0;
  return 1;
}

static vec3 reflect(vec3 I, vec3 N) {
  return vec3_sub(I, vec3_scale(2.f*vec3_dot(I,N),N));
}

static vec3 refract(vec3 I, vec3 N, float eta_t, float eta_i /* =1.f */) {
  // Snell's law
  float cosi = -max(-1.f, min(1.f, vec3_dot(I,N)));
  // if the ray comes from the inside the object, swap the air and the media  
  if (cosi<0) return refract(I, vec3_neg(N), eta_i, eta_t); 
    float eta = eta_i / eta_t;
    float k = 1 - eta*eta*(1 - cosi*cosi);
    // k<0 = total reflection, no ray to refract.
    // I refract it anyways, this has no physical meaning
    return k<0 ? make_vec3(1,0,0)
              : vec3_add(vec3_scale(eta,I),vec3_scale((eta*cosi - sqrtf(k)),N));
}

static BOOL scene_intersect(
   vec3 orig, vec3 dir, Sphere* spheres, int nb_spheres,
   vec3* hit, vec3* N, Material* material
) {
  float spheres_dist = 1e30;
  for(int i=0; i<nb_spheres; ++i) {
    float dist_i;
    if(
       Sphere_ray_intersect(&spheres[i], orig, dir, &dist_i) &&
       (dist_i < spheres_dist)
    ) {
      spheres_dist = dist_i;
      *hit = vec3_add(orig,vec3_scale(dist_i,dir));
      *N = vec3_normalize(vec3_sub(*hit, spheres[i].center));
      *material = spheres[i].material;
    }
  }
  float checkerboard_dist = 1e30;
  if (fabs(dir.y)>1e-3)  {
    float d = -(orig.y+4)/dir.y; // the checkerboard plane has equation y = -4
    vec3 pt = vec3_add(orig, vec3_scale(d,dir));
    if (d>0 && fabs(pt.x)<10 && pt.z<-10 && pt.z>-30 && d<spheres_dist) {
      checkerboard_dist = d;
      *hit = pt;
      *N = make_vec3(0,1,0);
      material->diffuse_color =
	(((int)(.5*hit->x+1000) + (int)(.5*hit->z)) & 1)
	             ? make_vec3(.3, .3, .3)
	             : make_vec3(.3, .2, .1);
    }
  }
  return min(spheres_dist, checkerboard_dist)<1000;
}

static vec3 cast_ray(
   vec3 orig, vec3 dir, Sphere* spheres, int nb_spheres,
   Light* lights, int nb_lights, int depth /* =0 */
) {
  vec3 point,N;
  Material material = make_Material_default();
  if (
    depth>2 ||
    !scene_intersect(orig, dir, spheres, nb_spheres, &point, &N, &material)
  ) {
    float s = 0.5*(dir.y + 1.0);
    return vec3_add(
	vec3_scale(s,make_vec3(0.2, 0.7, 0.8)),
        vec3_scale(s,make_vec3(0.0, 0.0, 0.5))
    );
  }

  vec3 reflect_dir=vec3_normalize(reflect(dir, N));
  vec3 refract_dir=vec3_normalize(refract(dir,N,material.refractive_index,1));
  
  // offset the original point to avoid occlusion by the object itself 
  vec3 reflect_orig =
    vec3_dot(reflect_dir,N) < 0
               ? vec3_sub(point,vec3_scale(1e-3,N))
               : vec3_add(point,vec3_scale(1e-3,N)); 
  vec3 refract_orig =
    vec3_dot(refract_dir,N) < 0
               ? vec3_sub(point,vec3_scale(1e-3,N))
               : vec3_add(point,vec3_scale(1e-3,N));
  vec3 reflect_color = cast_ray(
       reflect_orig, reflect_dir, spheres, nb_spheres,
       lights, nb_lights, depth + 1
  );
  vec3 refract_color = cast_ray(
       refract_orig, refract_dir, spheres, nb_spheres,
       lights, nb_lights, depth + 1
  );
  
  float diffuse_light_intensity = 0, specular_light_intensity = 0;
  for (int i=0; i<nb_lights; i++) {
    vec3  light_dir = vec3_normalize(vec3_sub(lights[i].position,point));
    float light_distance = vec3_length(vec3_sub(lights[i].position,point));

    vec3 shadow_orig =
      vec3_dot(light_dir,N) < 0
                ? vec3_sub(point,vec3_scale(1e-3,N))
                : vec3_add(point,vec3_scale(1e-3,N)) ;
    // checking if the point lies in the shadow of the lights[i]
    vec3 shadow_pt, shadow_N;
    Material tmpmaterial;
    if (
       scene_intersect(
	 shadow_orig, light_dir, spheres, nb_spheres,
	 &shadow_pt, &shadow_N, &tmpmaterial
       ) && (
  	 vec3_length(vec3_sub(shadow_pt,shadow_orig)) < light_distance
	     )
    ) continue ;
    
    diffuse_light_intensity  +=
                  lights[i].intensity * max(0.f, vec3_dot(light_dir,N));
     
    float abc = max(
	           0.f, vec3_dot(vec3_neg(reflect(vec3_neg(light_dir), N)),dir)
	        );
    float def = material.specular_exponent;
    if(abc > 0.0f && def > 0.0f) {
      specular_light_intensity += powf(abc,def)*lights[i].intensity;
    }
  }
  vec3 result = vec3_scale(
      diffuse_light_intensity * material.albedo.x, material.diffuse_color
  );
  result = vec3_add(
       result, vec3_scale(specular_light_intensity * material.albedo.y,
       make_vec3(1,1,1))
  );
  result = vec3_add(result, vec3_scale(material.albedo.z, reflect_color));
  result = vec3_add(result, vec3_scale(material.albedo.w, refract_color));
  return result;
}


static void render(Sphere* spheres, int nb_spheres, Light* lights, int nb_lights) {
   const float fov  = M_PI/3.;
   stats_begin_frame();
   for (int j = 0; j<graphics_height; j++) { // actual rendering loop
      for (int i = 0; i<graphics_width; i++) {
	stats_begin_pixel();
	float dir_x =  (i + 0.5) - graphics_width/2.;
	float dir_y = -(j + 0.5) + graphics_height/2.; // this flips the image.
	float dir_z = -graphics_height/(2.*tan(fov/2.));
	vec3 C = cast_ray(
	   make_vec3(0,0,0), vec3_normalize(make_vec3(dir_x, dir_y, dir_z)),
	   spheres, nb_spheres, lights, nb_lights, 0
	);
	graphics_set_pixel(i,j,C.x,C.y,C.z);
	stats_end_pixel();
      }
      flush_l2_cache(); // needed for femtorv32 + LiteX (L2 cache -> framebuffer transfer)
      if (readchar_nonblock()) {
	 getchar();
	 return;
      }
   }
   stats_end_frame();
}

int nb_spheres = 4;
Sphere spheres[4];

int nb_lights = 3;
Light lights[3];

static void init_scene(void) {
    Material ivory = make_Material(
       1.0, make_vec4(0.6,  0.3, 0.1, 0.0), make_vec3(0.4, 0.4, 0.3),   50.
    );
    Material glass = make_Material(
       1.5, make_vec4(0.0,  0.5, 0.1, 0.8), make_vec3(0.6, 0.7, 0.8),  125.
    );
    Material red_rubber = make_Material(
       1.0, make_vec4(0.9,  0.1, 0.0, 0.0), make_vec3(0.3, 0.1, 0.1),   10.
    );
    Material mirror = make_Material(
       1.0, make_vec4(0.0, 10.0, 0.8, 0.0), make_vec3(1.0, 1.0, 1.0),  142.
    );

    spheres[0] = make_Sphere(make_vec3(-3,    0,   -16), 2,      ivory);
    spheres[1] = make_Sphere(make_vec3(-1.0, -1.5, -12), 2,      glass);
    spheres[2] = make_Sphere(make_vec3( 1.5, -0.5, -18), 3, red_rubber);
    spheres[3] = make_Sphere(make_vec3( 7,    5,   -18), 4,     mirror);

    lights[0] = make_Light(make_vec3(-20, 20,  20), 1.5);
    lights[1] = make_Light(make_vec3( 30, 50, -25), 1.8);
    lights[2] = make_Light(make_vec3( 30, 20,  30), 1.7);
}


static void run_tinyraytracer(void) {
    printf("===== TINYRAYTRACER ====\n");
    init_scene();
    graphics_init();
    render(spheres, nb_spheres, lights, nb_lights);
    graphics_terminate();
}

static void tinyraytracer(int nb_args, char** args) {
   benchmark = 0;
   run_tinyraytracer();
}
define_demo(tinyraytracer, "tinyraytracer (by Dmitry Sokolov)");

static void raystones(int nb_args, char** args) {
   benchmark = 1;   
   run_tinyraytracer();
}
define_demo(raystones, "raystones (uses tinyraytracer by Dmitry Sokolov)");



