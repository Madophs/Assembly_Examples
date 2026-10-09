#include <string.h>
/*#include <stdio.h>*/
#include "../include/malloc.h"

extern void gc_init();
extern void gc_collect();

struct person {
    char name[32];
    int age;
};

void pointer_goes_out_of_scope() {
    int *num = allocate(sizeof(int));
    *num = 0x1000;
    long *num2 = allocate(sizeof(long));
    *num2 = 32;
    gc_collect();
}

int *static_ptr = 0;
char *hola = "hola mundo";
struct person *nier;

int main() {
    gc_init();
    static_ptr = allocate(sizeof(int));
    *static_ptr = 255;

    char *text = allocate(sizeof(char) * 50);
    strcpy(text, "hola soy local");

    nier = allocate(sizeof(struct person));
    strcpy(nier->name, "Nier automata");
    nier->age = 27;

    struct person *tigre = allocate(sizeof(struct person));
    strcpy(tigre->name, "Soy el tigre!");
    tigre->age = 99;

    pointer_goes_out_of_scope();
    long *val = allocate(sizeof(long));
    *val = 512;
    gc_collect();
    return 0;
}
