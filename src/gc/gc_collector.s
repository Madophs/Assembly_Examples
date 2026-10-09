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
    and $-0x1000, %rax
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
    mov %rdi, data_seg_size(%rip)
    xor %rax, %rax
    add $8, %rsp
    ret
gc_init_loop_next:
    add $PH_ENTRY_SIZE, %rax
    jmp gc_init_loop

.globl gc_collect
gc_collect:
    push %rbp
    mov %rsp, %rbp
    call gc_create_mem_block_table
    call gc_unmark_mem_blocks

    # data section scanning
    mov data_seg_start(%rip), %rdi
    mov %rdi, %rsi
    add data_seg_size(%rip), %rsi
    mov $8, %rdx
    call gc_scan_memory

    # heap section scanning
    # scanning the heap by 8 bytes hops is buggy
    # as the is heap usually not aligned to 8 bytes
    # but I set it up that way because is faster
    # If you want a better scan change rdx to 1
    mov heap_start(%rip), %rdi
    mov heap_end(%rip), %rsi
    mov $8, %rdx
    call gc_scan_memory

    call gc_scan_stack
    call gc_restore_heap

    xor %rax, %rax
    mov %rbp, %rsp
    pop %rbp
    ret

gc_restore_heap:
    sub $8, %rsp
    mov heap_end(%rip), %rdi
    mov $0xc, %rax
    syscall
    add $8, %rsp
    ret

gc_scan_stack:
    push %rbp
    mov %rsp, %rbp
    sub $16, %rsp
    mov heap_start(%rip), %rdi
    mov heap_end(%rip), %rsi
    mov stack_rbp(%rip), %rcx
gc_scan_stack_loop:
    cmp %rbp, %rcx
    jbe gc_scan_stack_finish
    # heap_start cmp
    cmp (%rcx), %rdi
    ja gc_scan_stack_end
    cmp (%rcx), %rsi
    jb gc_scan_stack_end

    push %rdi
    push %rcx

    mov (%rcx), %rdi
    call gc_mark_mem_block

    pop %rcx
    pop %rdi
gc_scan_stack_end:
    sub $8, %rcx
    jmp gc_scan_stack_loop
gc_scan_stack_finish:
    mov %rbp, %rsp
    pop %rbp
    ret

gc_create_mem_block_table:
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

    # extra 16 bytes to store memory block count
    add $0x10, %rax

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

    # start at heap_start (memory block traversing)
    mov 24(%rsp), %rcx

    # construct heap ptr table beyond heap end
    mov 16(%rsp), %rsi

    # we will use the first 16 bytes of heap memory table
    # to store the counter (rdx)
    xor %rdx, %rdx
    # make sure counter location is zero
    mov %rdx, (%rsi)
    mov %rdx, 8(%rsi) # not required but anyway...
    # advance table pointer pass the counter
    add $0x10, %rsi
gc_create_mem_block_table_loop:
    # heap_end - curr heap address
    cmp 16(%rsp), %rcx
    jae gc_create_mem_block_table_loop_finish

    # store block start address in heap ptr table
    mov %rcx, (%rsi)
    add $8, %rsi

    # memory block counter
    inc %rdx

    # continue to next block
    # block size
    mov 8(%rcx), %rdi
    add %rdi, %rcx
    # header size
    add $16, %rcx
    jmp gc_create_mem_block_table_loop

gc_create_mem_block_table_loop_finish:
    # update memory counter at table start
    mov 16(%rsp), %rsi
    mov %rdx, (%rsi)
    # return ptr table's end address
    mov (%rsp), %rax
    mov %rbp, %rsp
    pop %rbp
    ret

# params:
#   rdi -> start memory location
#   rsi -> end memory location
#   rdx -> byte hop size
gc_scan_memory:
    push %rbp
    mov %rsp, %rbp
    mov heap_start(%rip), %r8
    mov heap_end(%rip), %r9
gc_scan_memory_loop:
    cmp %rsi, %rdi
    jae gc_scan_memory_loop_finish
    # dereference data contigent "pointer"
    mov (%rdi), %rcx
    cmp %r8, %rcx
    jb gc_scan_memory_loop_end
    cmp %r9, %rcx
    ja gc_scan_memory_loop_end
gc_scan_memory_hit:
    push %rcx
    push %rdi
    mov %rcx, %rdi
    call gc_mark_mem_block
    pop %rdi
    pop %rcx
gc_scan_memory_loop_end:
    add %rdx, %rdi
    jmp gc_scan_memory_loop
gc_scan_memory_loop_finish:
    mov %rbp, %rsp
    pop %rbp
    ret

# mark memory block as non-free if valid
gc_mark_mem_block:
    sub $8, %rsp
    mov heap_end(%rip), %rax
    # make pointer point at the beginning of the memory block
    sub $0x10, %rdi
    # memory counter
    mov (%rax), %rcx
    # advance pass the memory counter
    add $0x10, %rax
gc_mark_mem_block_loop:
    cmp $0, %rcx
    jz gc_mark_mem_block_finish
    cmp (%rax), %rdi
    jne gc_mark_mem_block_loop_end
    mov $1, %r8
    mov (%rax), %rax
    mov %r8, (%rax)
    jmp gc_mark_mem_block_finish
gc_mark_mem_block_loop_end:
    dec %rcx
    add $8, %rax
    jmp gc_mark_mem_block_loop
gc_mark_mem_block_finish:
    add $8, %rsp
    ret


# set as available all memory block allocated by allocate function
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
