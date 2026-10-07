#include <stdio.h>
#include "../include/malloc.h"

void main_finish() {
    printf("Just finished\n");
}

int main() {
    int bytes = 8;
    for (int i = 1; i < 5; ++i) {
        int *p1 = allocate(bytes);
        *p1 = 25 * i;
        if (i == 2) {
            deallocate(p1);
        }
        printf("%p %d\n", p1, *p1);
    }
    int *p2 = allocate(0);
    printf("%p\n", p2);

    main_finish();
    return 0;
}
