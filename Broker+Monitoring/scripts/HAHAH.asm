.global _start
.intel_syntax noprefix
_start:
mov     rax, 1
mov     rdi, 1
mov     rsi, hello
mov     rdx, 14
syscall
mov     rax, 60
mov     rdi, 1
syscall

hello: .asciz "Hello, World!\n"