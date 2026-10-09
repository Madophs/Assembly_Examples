#include <string.h>
/*#include <stdio.h>*/
#include "../include/malloc.h"

extern void gc_init();
extern void gc_collect();

struct person {
    char name[32];
    int age;
};

int *static_ptr = 0;
char c = 'a';
long ghost_address = 0;
char *hola = "hola mundo";
struct person *nier;

void pointer_goes_out_of_scope() {
    int *num = allocate(sizeof(int));
    *num = 0x1000;
    long *num2 = allocate(sizeof(long));
    *num2 = 32;
    char *ghost_text = allocate(sizeof(char) * 64);
    strcpy(ghost_text, "This is a ghost pointer");
    ghost_address = (long)&(*ghost_text);
    gc_collect();
}

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
    c = 'z';
    gc_collect();
    return 0;
}
