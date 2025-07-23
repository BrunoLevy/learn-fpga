#include <femtoGL.h>
#include <keyboard.h>

static int show_list(char* title, char** options, int sel) {
    GL_tty_goto_xy(0,0);
    GL_clear();
    GL_set_bg(0,0,0);
    GL_set_fg(200,200,200);
    printf("%s\n\n",title);
    int cur;
    for(cur=0; options[cur]; ++cur) {
       if(cur == sel) {
	  GL_set_fg(0,0,0);
	  GL_set_bg(255,255,255);
       } 
       printf("%s\n",options[cur]);
       if(cur == sel) {
	  GL_set_bg(0,0,0);
	  GL_set_fg(255,255,255);
       }		
    }
    return cur;
}

int GUI_button() {
    int key;
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
    key = UART_pollkey();
    switch(key) {
    case KEY_UP:
      result = 2;
      break;
    case KEY_DOWN:
      result = 3;
      break;
    case KEY_RIGHT:
    case KEY_ENTER:
    case ' ':
      result = 5;
      break;
    case KEY_LEFT:
      result = 4;
      break;
    }
    
    return result;
}

int GUI_prompt(char* title, char** options) {
   GL_tty_init(GL_MODE_OLED);
   int sel = 0;
   int nb_options = show_list(title, options, sel);   
   for(;;) {
      int btn = GUI_button();
      switch(btn) {
       case 2: sel--; break;
       case 3: sel++; break;
       case 5: return sel; break;
      }
      sel = MAX(sel,0);
      sel = MIN(sel,nb_options-1);
      if(btn != 0 && btn != -1) {
	 show_list(title, options, sel);
      }
   }
}
