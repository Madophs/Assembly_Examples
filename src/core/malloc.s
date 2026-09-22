# This doesn't attempt to replicate malloc functionality
# Just a simple naive implementation
.globl allocate
.globl deallocate
# header tells if block is used and the size, 8 bytes for each
.section .data
heap_start:
    .quad 0
heap_end:
    .quad 0
.section .text

.equ BRK_SYSCALL, 12
.equ BLOCK_AVAIL_OFFSET, 0
.equ BLOCK_SIZE_OFFSET, 8
.equ HEADER_SIZE, 16

allocate:
    # we need allocate at least 1 byte
    cmp $0, %rdi
    je return_null

    # Allign block to 16bytes
    add $15, %rdi
    and $-16, %rdi

    # immediately save requested size in r8
    mov %rdi, %r8
    mov heap_start(%rip), %rax
    cmp $0, %rax
    jnz allocate_loop

allocate_init:
    mov $BRK_SYSCALL, %rax
    # when brk is called with 0 as argument it will populate %rax with the heap address
    mov $0, %rdi
    syscall
    # set heap address
    mov %rax, heap_start(%rip)
    mov %rax, heap_end(%rip)
    jmp move_brk

allocate_loop:
    cmp heap_end(%rip), %rax
    jae move_brk # we have reach the end of heap
    # Check if block is assign. 0/1 => false/true
    mov BLOCK_AVAIL_OFFSET(%rax), %rcx
    cmp $1, %rcx
    je allocate_loop_end
    # Check if requested block size (r8) fits
    mov BLOCK_SIZE_OFFSET(%rax), %rcx
    cmp %r8, %rcx
    jb allocate_loop_end

    mov %rax, %rsi
    jmp allocate_assign

allocate_loop_end:
    mov BLOCK_SIZE_OFFSET(%rax), %rcx
    add %rcx, %rax
    add $HEADER_SIZE, %rax
    jmp allocate_loop

move_brk:
    # Save new block's starting location on rsi
    mov %rax, %rsi

    mov $BRK_SYSCALL, %rax
    mov heap_end(%rip), %rdi
    add %r8, %rdi
    add $HEADER_SIZE, %rdi
    syscall

    # If heap didn't change, means brk fail to allocate more size
    cmp heap_end(%rip), %rax
    je return_null

    # Update head's end location
    mov %rax, heap_end(%rip)

allocate_assign:
    mov $1, %rdi
    mov %rdi, BLOCK_AVAIL_OFFSET(%rsi)
    mov %r8, %rcx
    mov %rcx, BLOCK_SIZE_OFFSET(%rsi)
    jmp allocate_finish

allocate_finish:
    mov %rsi, %rax
    add $HEADER_SIZE, %rax
    ret

deallocate:
    mov $0, %rcx
    mov %rcx, -HEADER_SIZE(%rdi)
    ret

return_null:
    mov $0, %rax
    ret
