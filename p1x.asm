org 0x100

mov ah, 0x09
mov dx, msg
int 0x21
    
mov ax, 0x4C
int 0x21

msg db 'P1X$'