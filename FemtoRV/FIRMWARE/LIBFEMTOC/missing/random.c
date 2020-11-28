#include "../femtostdlib.h"

static int randomseed = 1;

int random() {
    randomseed = (randomseed * 1366l + 150889l) % 714025l;
    return randomseed;
}
