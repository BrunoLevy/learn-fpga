#include <femtorv32.h>

// Game of life, displayed on the 8x8 led matrix
// (naive implementation)

char buff1[8][8] = {
   {0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0},
   {0,0,0,0,0,1,0,0},
   {0,0,0,0,1,0,0,0},
   {0,0,0,0,1,1,1,0},
   {0,1,0,0,0,0,0,0},   
   {1,0,0,0,0,0,0,0},
   {1,1,1,0,0,0,0,0}
};

char buff2[8][8];

void next() {
   for(int i=0; i<8; ++i) {
      for(int j=0; j<8; ++j) {
	 int im = (i==0)?7:(i-1);
	 int ip = (i+1)&7;
	 int jm = (j==0)?7:(j-1);
	 int jp = (j+1)&7;
	 int nb_neigh =
	   buff1[im][jm] +
	   buff1[im][j] +
	   buff1[im][jp] +
	   buff1[i][jm] +
	   buff1[i][jp] +
	   buff1[ip][jm] +
	   buff1[ip][j] +
	   buff1[ip][jp] ;
	 buff2[i][j] = ((nb_neigh == 3) || (nb_neigh == 2 && buff1[i][j])) ? 1 : 0;
      }
   }
   for(int i=0; i<8; ++i) {
      for(int j=0; j<8; ++j) {
	 buff1[i][j] = buff2[i][j];
      }
   }
}


void show() {
   for(int i=0; i<8; ++i) {
      MAX7219(
	      i+1,
	       buff1[i][0]       |
	      (buff1[i][1] << 1) |
	      (buff1[i][2] << 2) |
	      (buff1[i][3] << 3) |
	      (buff1[i][4] << 4) |
	      (buff1[i][5] << 5) |
	      (buff1[i][6] << 6) |
	      (buff1[i][7] << 7) 
      );
   }
}

int main() {
   MAX7219_tty_init();
   printf("Game of Life ");
   delay(1000);
   for(;;) {
      show();
      delay(150);
      next();
   }
}

