#include <femtorv32.h>
#include <femtostdlib.h>

#define PATH_LEN 255

int sel = 0;
char* cwd = "/";

int is_executable(const char* filename) {
    int l = strlen(filename);
    return (l >= 4 && !strcmp(filename + l - 4, ".bin"));
}

void refresh() {
    GL_tty_goto_xy(0,0);
    GL_clear();
    FL_DIR dirstat;
    int cur = 0;
    if (fl_opendir(cwd, &dirstat)) {
        struct fs_dir_ent dirent;
        while (fl_readdir(&dirstat, &dirent) == 0) {
            if (dirent.is_dir || is_executable(dirent.filename)) {
		if(cur == sel) {
		    GL_set_fg(0,0,0);
		    GL_set_bg(255,255,255);
		} 
		printf("%s\n",dirent.filename);
		if(cur == sel) {
		    GL_set_bg(0,0,0);
		    GL_set_fg(255,255,255);
		}		
		++cur;
            }
        }
        fl_closedir(&dirstat);
    }
}

void call_exec() {
    char buff[PATH_LEN];
    FL_DIR dirstat;
    int cur = 0;
    if (fl_opendir(cwd, &dirstat)) {
        struct fs_dir_ent dirent;
        while (fl_readdir(&dirstat, &dirent) == 0) {
            if (dirent.is_dir || is_executable(dirent.filename)) {
		if(cur == sel && is_executable(dirent.filename)) {
		    strcpy(buff, cwd);
		    strcpy(buff+strlen(buff), dirent.filename);
		    exec(buff);	      
		}
		++cur;
            }
        }
        fl_closedir(&dirstat);
    }
}

int button() {
    int result = -1;
    static uint32_t btn_state = 0;
    uint32_t new_state = IO_IN(IO_BUTTONS);
    if(new_state != btn_state) {
	for(int i=0; i<6; ++i) {
	    if(((btn_state & (1 << i)) != (new_state & (1 << i)))) {
		if(new_state & (1 << i)) {
		    result = i;
		    break;
		}
	    }
	}
	btn_state = new_state;
    }
    return result;
}

int main() {
    GL_tty_init();
    if(sd_init()) {
	printf("Could not initialize SDCard\n");
	return 1;
    }
    printf("SDCard OK\n");
    fl_init();
    printf("fl initialized OK\n");
    if(fl_attach_media((fn_diskio_read)sd_readsector, (fn_diskio_write)sd_writesector) != FAT_INIT_OK) {
	printf("ERROR: Failed to init file system\n");
	return -1;
    }
    printf("FileSystem OK\n");
    refresh();
    for(;;) {
	int btn = button();
	switch(btn) {
	    case 2: sel--; break;
	    case 3: sel++; break;
	    case 5: call_exec(); break;
	}
	if(btn != 0 && btn != -1) {
	    refresh();
	}
    }
}
