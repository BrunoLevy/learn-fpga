
int fact(int x) {
   return (x==1) ? 1 : x*fact(x-1);
}

int main() {
   int x = 3;
   int y = fact(x);
   return 0;
}

