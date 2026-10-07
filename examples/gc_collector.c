#include <string.h>
/*#include <stdio.h>*/
#include "../include/malloc.h"

extern void gc_init();
extern void gc_unmark_mem_blocks();
extern void * gc_create_heap_ptr_table();
extern void gc_scan_data_section();

struct person {
    char name[32];
    int age;
};

void pointer_goes_out_of_scope() {
    int *num = allocate(sizeof(int));
    *num = 0x1000;
    long *num2 = allocate(sizeof(long));
    *num2 = 32;
}

int *static_ptr = 0;
char *hola = "hola mundo";
struct person *nier;

int main() {
    gc_init();
    static_ptr = allocate(sizeof(int));
    char *text = allocate(sizeof(char) * 10);
    strcpy(text, "hola");
    nier = allocate(sizeof(struct person));
    strcpy(nier->name, "jehu jair");
    nier->age = 27;

    pointer_goes_out_of_scope();
    gc_create_heap_ptr_table();
    gc_unmark_mem_blocks();
    gc_scan_data_section();
    return 0;
}
