#include <femtoGL.h>
#include <femtostdlib.h>
#include <fat_io_lib/fat_filelib.h>
#include <femto_elf.h>

#define FONT_HEIGHT 8
#define LINES OLED_HEIGHT / FONT_HEIGHT
#define PATH_LEN 150

const char* INVALID_ARGUMENTS = "\nInvalid arguments\n";

void print_elf_error(int errcode) {
  if(errcode != ELF32_OK) {
    switch(errcode) {
    case ELF32_FILE_NOT_FOUND:
      printf("\nNot found\n");
      break;
    case ELF32_HEADER_SIZE_MISMATCH:
      printf("\nELF hdr mismatch\n");
      break;
    case ELF32_READ_ERROR:
      printf("\nRead err\n");
      break;
    default:
      printf("\nUnknown err\n");
      break;
    }
  }
}

/*
 * TODO: support browsing subdirectories.
 */ 

char cwd[PATH_LEN];

int is_executable(const char* filename) {
    int l = strlen(filename);
    return
      (l >= 4 && !strcmp(filename + l - 4, ".bin")) ||
      (l >= 4 && !strcmp(filename + l - 4, ".elf")) ;
}

/*
 * \param[in] from the index to start display from
 * \param[in] sel the index of the currently selected file
 * \returns the total number of files 
 */
int refresh(int from, int sel) {
    GL_tty_goto_xy(0,0);
    GL_clear();
    FL_DIR dirstat;
    int cur = 0;
    int result = 0;
    if (fl_opendir(cwd, &dirstat)) {
        struct fs_dir_ent dirent;
        while (fl_readdir(&dirstat, &dirent) == 0) {
	   if (/*!dirent.is_dir &&*/ !is_executable(dirent.filename)) {
	      continue;
	   }
	   if(cur >= from && cur < from + LINES) {
	      if(cur == sel) {
		 GL_set_fg(0,0,0);
		 GL_set_bg(255,255,255);
	      }
	      char current[PATH_LEN];
	      int l = strlen(dirent.filename);
	      strncpy(current, dirent.filename,MIN(l-4,14));
	      current[14] = '.';
	      current[15] = '\0';
	      current[l-4] = '\0';
	      printf("%s\n",current);
	      if(cur == sel) {
		 GL_set_bg(0,0,0);
		 GL_set_fg(255,255,255);
	      }		
	   }
	   ++cur;
        }
        fl_closedir(&dirstat);
    }
    return cur;
}

void call_exec(int sel) {
    char buff[PATH_LEN];
    FL_DIR dirstat;
    int cur = 0;
    int errcode;
    if (fl_opendir(cwd, &dirstat)) {
        struct fs_dir_ent dirent;
        while (fl_readdir(&dirstat, &dirent) == 0) {
	    if (is_executable(dirent.filename)) {
		if(cur == sel && is_executable(dirent.filename)) {
		    strcpy(buff, cwd);
		    strcpy(buff+strlen(buff), dirent.filename);
		    errcode = exec(buff, 0, NULL);
		    print_elf_error(errcode);
		    exit(0); // workaround for executables that do not call exit().
		}
		++cur;
            }
        }
        fl_closedir(&dirstat);
    }
}

/* declared as globals so that they are persistent. */
int sel=0;
int from=0;

int shell_exec(int argc, char* argv[]) {
  if(argc == 0) {
     return 1;
  }
  char buff[PATH_LEN];
  if(!strcmp(argv[0],"exit")) {
     return 0;
  } else if(!strcmp(argv[0],"ls")) {
     fl_listdirectory(cwd);
  } else if(!strcmp(argv[0],"pwd")) {
     printf("\n%s\n",cwd);
  } else if(!strcmp(argv[0],"mode")) {
     if(argc != 2) {
       printf(INVALID_ARGUMENTS);
     } else {
       int mode = atoi(argv[1]);
       if(mode < 0 || mode >= FGA_NB_MODES) {
	 printf(INVALID_ARGUMENTS);
       } else {
	 GLFont* font = GL_current_font;
	 GL_tty_init(mode);
	 GL_set_font(font); 
       }
     }
  } else if(!strcmp(argv[0],"font")) {
     if(argc != 2) {
       printf(INVALID_ARGUMENTS);
     } else {
       GL_tty_init(FGA_mode);
       int font = atoi(argv[1]);
       switch(font) {
       case 0:
	 GL_set_font(&Font3x5);
	 break;
       case 1:
	 GL_set_font(&Font5x6);
	 break;
       case 2:
	 GL_set_font(&Font8x8);
	 break;
       case 3:
	 GL_set_font(&Font8x16);
	 break;
       default:
	 printf(INVALID_ARGUMENTS);
	 break;
       }
     }
  } else {
     printf("\n");
     strcpy(buff,cwd);
     strcpy(buff+strlen(buff),argv[0]);
     strcpy(buff+strlen(buff),".elf");     
     int errcode = exec(buff, argc, argv);
     print_elf_error(errcode);
  }
  return 1; 
}

void shell() {
   char cmdline[PATH_LEN];
   char* ptr = cmdline;
   int argc;
   char* argv[100];
   
   char blink = 0;
   uint64_t t0 = cycles();
   uint64_t t1;
   uint64_t nb_cycles = 250 * 1000 * FEMTORV32_FREQ;

   
   GL_tty_init(FGA_MODE_800x600x2bpp);
   GL_set_font(&Font8x16);
   printf("FemtOS v. 0.0\n");
   putchar(']');
   for(;;) {
      char cursor = (GL_current_font == &Font8x16) ? 178 : '_';
      int c = UART_pollkey();
      if(c == 0) {
	 t1 = cycles();
	 if(t1 - t0 > nb_cycles) {
	    t0 = t1;
	    blink = !blink;
	    putchar(blink ? cursor : ' ');
	    putchar('\r');
	 }
	 continue;
      } else {
	 putchar(' ');
	 putchar('\r');
      }
      if(c == 8) {
	if(ptr > cmdline) {
	  putchar('\r');
	  putchar(' ');
	  putchar('\r');
	  *ptr = '\0';
	  --ptr;
	}
      } else if(c != 10 && c !=13) {
	 putchar(c);
	 if(ptr < cmdline + PATH_LEN-2) {
	   *ptr = c;
	   ptr++;
	 }
      } else if(c == 13) {
	 *ptr = '\0';
	 argc = 0;
	 for(ptr=strtok(cmdline," "); ptr; ptr=strtok(NULL," ")) { 
	    argv[argc] = ptr;
	    ++argc;
	 }
	 ptr = cmdline;
	 if(!shell_exec(argc, argv)) {
	   break;
	 }
	 putchar('\n');
	 putchar(']');
      }
   }
   GL_tty_init(GL_MODE_OLED);
}


int main() {
    strcpy(cwd,"/");
    int nb = 0;
    GL_tty_init(GL_MODE_OLED);
    if(filesystem_init() != 0) {
       return -1;
    }
    nb = refresh(from,sel);
    /* 
     * Re-constrain sel and nb in case SDCard was
     * changed between two invocations.
     */
    if(sel < 0) {
       sel = 0;    
    }
    if(sel >= nb) { 
       sel = nb-1; 
    }
    from = MIN(from, sel);
    from = MAX(from, sel-LINES+1);
    nb = refresh(from,sel);   
   
    for(;;) {
	int btn = GUI_button();
	switch(btn) {
	    case 2: sel--; break;
	    case 3: sel++; break;
	    case 5: call_exec(sel); break;
   	    case 4: shell(); break;
	}
        if(sel < 0) {
	   sel = 0;    
	}
        if(sel >= nb) { 
	   sel = nb-1; 
	}
	if(btn != 0 && btn != -1) {
	   from = MIN(from, sel);
	   from = MAX(from, sel-LINES+1);
	   nb = refresh(from,sel);
	}
    }
}
