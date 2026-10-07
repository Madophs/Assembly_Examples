.globl heap_start
.hidden heap_start
.globl heap_start
.hidden heap_end
.hidden _end

.data
# base virtual address location
proc_addr_start:
    .quad 0
# stack base pointer usually initialized in main function
stack_rbp:
    .quad 0
# Program Header address
ph_load:
    .quad 0
# data segment
ph_data_seg:
    .quad 0
data_seg_start:
    .quad 0
data_seg_size:
    .quad 0
.text

# PH_LOAD is 64 bytes after program start address
.equ PH_LOAD_OFFSET, 0x40

# Program Header entry offset in bytes
.equ PH_ENTRY_SIZE, 0x38
.equ PH_TYPE, 0x0
.equ PH_FLAGS, 0x4
.equ PH_OFFSET, 0x8
.equ PH_VIRT_ADDR, 0x10
.equ PH_MEMSIZ, 0x28

# Should be called at main
.globl gc_init
gc_init:
    sub $8, %rsp
    mov %rbp, stack_rbp(%rip)
    # address to return after call (main)
    mov 8(%rsp), %rax
    # compute text segment address
    and $-0xfff, %rax
    # header address aka program base address
    sub $0x1000, %rax
    mov %rax, proc_addr_start(%rip)
    # Program Header address
    add $PH_LOAD_OFFSET, %rax
    mov %rax, ph_load(%rip)
    # search for data segment entry in PH_LOAD
gc_init_loop:
    movl PH_TYPE(%rax), %esi
    cmp $1, %esi # PT_LOAD loadable segment
    jne gc_init_loop_next
    movl PH_FLAGS(%rax), %esi
    cmp $6, %esi # RW
    jne gc_init_loop_next
    # this most be the data entry
    mov %rax, ph_data_seg(%rip)
    # save data segment virtual address
    mov PH_VIRT_ADDR(%rax), %rdi
    # calculate data section start address
    add $0xfff, %rdi
    and $-0x1000, %rdi
    add proc_addr_start(%rip), %rdi
    mov %rdi, data_seg_start(%rip)
    # calculate data section size
    mov PH_MEMSIZ(%rax), %rdi
    #add $0xfff, %rdi
    #and $-0x1000, %rdi
    mov %rdi, data_seg_size(%rip)
    xor %rax, %rax
    add $8, %rsp
    ret
gc_init_loop_next:
    add $PH_ENTRY_SIZE, %rax
    jmp gc_init_loop

.globl gc_traverse_stack
gc_traverse_stack:
    push %rbp
    mov %rsp, %rbp
    sub $16, %rsp
    mov heap_start(%rip), %rax
    mov %rax, 8(%rsp)
    mov heap_end(%rip), %rax
    mov %rax, (%rsp)
    mov stack_rbp(%rip), %rcx
gc_traverse_stack_loop:
    cmp %rbp, %rcx
    jae gc_traverse_stack_finish
    # heap_start cmp
    cmp 8(%rsp), %rcx
    jb gc_traverse_stack_end
    # heap end cmp
    cmp (%rsp), %rcx
    ja gc_traverse_stack_end
gc_traverse_stack_end:
    add $8, %rcx
    jmp gc_traverse_stack_loop
gc_traverse_stack_finish:
    mov %rbp, %rsp
    pop %rbp
    ret

.globl gc_create_heap_ptr_table
gc_create_heap_ptr_table:
    push %rbp
    mov %rsp, %rbp
    sub $32, %rsp
    mov heap_start(%rip), %rax
    mov %rax, 24(%rsp)
    mov heap_end(%rip), %rax
    mov %rax, 16(%rsp)

    # allocate twice the heap size to store memory block data
    # compute heap size
    sub 24(%rsp), %rax

    # store heap size
    mov %rax, 8(%rsp)
    # add heap_end's address to heap_size (rax)
    add 16(%rsp), %rax

    # save target heap address in rdi/stack
    mov %rax, %rdi
    mov %rdi, (%rsp)

    # BRK syscall
    mov $12, %rax
    syscall
    cmp %rax, %rdi
    jne gc_return_with_error

    # start at heap_start
    mov 24(%rsp), %rcx

    # start heap ptr table address (heap_end)
    mov 16(%rsp), %rsi
gc_create_heap_ptr_table_loop:
    # heap_end - curr heap address
    cmp 16(%rsp), %rcx
    jae gc_create_heap_ptr_table_loop_finish

    # store block start address in heap ptr table
    mov %rcx, (%rsi)
    add $8, %rsi

    # continue to next block
    # block size
    mov 8(%rcx), %rdi
    add %rdi, %rcx
    # header size
    add $16, %rcx
    jmp gc_create_heap_ptr_table_loop

gc_create_heap_ptr_table_loop_finish:
    # return ptr table's end address
    mov (%rsp), %rax
    mov %rbp, %rsp
    pop %rbp
    ret

.globl gc_scan_data_section
gc_scan_data_section:
    push %rbp
    mov %rsp, %rbp
    sub $16, %rsp
    mov heap_start(%rip), %rax
    mov %rax, 8(%rsp)
    mov heap_end(%rip), %rax
    mov %rax, (%rsp)
    # data section start address
    mov data_seg_start(%rip), %rcx
    # data section end address (bss)
    mov %rcx, %rdx
    add data_seg_size(%rip), %rdx
gc_scan_data_section_loop:
    cmp %rdx, %rcx
    jae gc_scan_data_section_loop_finish
    # dereference data contigent "pointer"
    mov (%rcx), %rsi
    cmp 8(%rsp), %rsi
    jb gc_scan_data_section_loop_end
    cmp (%rsp), %rsi
    ja gc_scan_data_section_loop_end
gc_scan_data_section_hit:
    mov $1, %r8
    mov %r8, -0x10(%rsi)
gc_scan_data_section_loop_end:
    inc %rcx
    jmp gc_scan_data_section_loop
gc_scan_data_section_loop_finish:
    mov $0, %rax
    mov %rbp, %rsp
    pop %rbp
    ret


# set as available all memory block allocated by allocate function
.globl gc_unmark_mem_blocks
gc_unmark_mem_blocks:
    push %rbp
    mov %rsp, %rbp
    sub $16, %rsp
    mov heap_start(%rip), %rax
    mov %rax, 8(%rsp)
    mov heap_end(%rip), %rax
    mov %rax, (%rsp)
    mov 8(%rsp), %rcx
    # register to unmark blocks
    mov $0, %rax
gc_unmark_mem_blocks_loop:
    # heap_end - curr heap address
    cmp (%rsp), %rcx
    jae gc_unmark_mem_blocks_finish
    # unmark memory block
    mov %rax, (%rcx)
    # block size
    mov 8(%rcx), %rdi
    # continue to next block
    add %rdi, %rcx
    # header size
    add $16, %rcx
    jmp gc_unmark_mem_blocks_loop

gc_unmark_mem_blocks_finish:
    mov %rbp, %rsp
    pop %rbp
    ret

gc_return_void:
    mov $0, %rax
    mov %rbp, %rsp
    pop %rbp
    ret

gc_return_with_error:
    mov $1, %rax
    mov %rbp, %rsp
    pop %rbp
    ret
