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

    // Will be free once goes out of scope
    long *num2 = allocate(sizeof(long));
    *num2 = 32;

    char *ghost_text = allocate(sizeof(char) * 64);
    strcpy(ghost_text, "This is a ghost pointer");
    // ghost_address is not pointer but holds the value of a valid one
    // this tricks the GC to think that there's a pointer
    // leading a positive-negative check
    ghost_address = (long)&(*ghost_text);

    // Bug in the heap, dangling pointer
    void **p_num = allocate(sizeof(long));
    *p_num = (void *)&(*num);

    gc_collect();
}

void outer_scope() {
    static_ptr = allocate(sizeof(int));
    *static_ptr = 255;

    // Later to be replace by jaguar once it goes out of scope
    // 50 bytes is enough hold person struct
    char *text_hola = allocate(sizeof(char) * 50);
    strcpy(text_hola, "Hola soy local");

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
}

int main() {
    gc_init();
    outer_scope();
    gc_collect();
    // text_hola is out of scope, to be replaced by jaguar
    struct person *jaguar = allocate(sizeof(struct person));
    strcpy(jaguar->name, "Hola soy jaguar");
    jaguar->age = 99;
    gc_collect();
    return 0;
}
