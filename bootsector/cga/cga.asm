[bits 16]
[org 0x7c00]

; ======== CONSTS ========
BUFFER equ 0x1000
TIMER equ 046Ch

; ======== GRAPHICS INITIALIZATION ========
start:
    mov ax, 0x0000    ; Init segments
    mov ds, ax
    mov ax, 0xB800
    mov es, ax
    mov ax, 0x0004    ; Set CGA mode 0x04 (320x200 in 4 colors)
    int 10h
    
    mov ax, BUFFER
    mov es, ax

; ======== GAME RESTART ========
restart_game:


; ======== GAME LOOP  ========
game_loop:

    ; ======== TEST DRAW ========

    xor di,di           ; Reset buffer pos to 0
    mov cx, 4           ; Gradient levels
    .draw_gradient:
    mov bx, 0    ; Sky starting color
    .next_color:
        push cx
        mov cx, 20        ; Adjust band size for lower resolution
        mov dx, 80        ; 320 pixels / 4 pixels per byte = 80 bytes per line
        mov al, bl  ; Set color for every group of pixels in a byte
    .draw_grad_line:
        push cx
        mov cx, dx
        rep stosb
        pop cx
        loop .draw_grad_line
        pop cx
        inc bx
        loop .next_color


    ; ======== KEYBOARD ========

    .handle_keyboard:
        mov ah, 0x01            ; Check if a key has been pressed
        int 0x16
        jz .no_kb               ; Jump if no key is in the keyboard buffer
        mov ah, 0x00            ; Get the key press
        int 0x16
        cmp ah, 0x01            ; Check if the scan code is for the [Esc] key
        je  restart_game
    .no_kb:

    ; ======== BLIT ========
    blit:
        push es
        push ds
        mov ax, 0xB800  ; CGA memory
        mov bx, BUFFER  ; Buffer memory
        mov es, ax
        mov ds, bx
        mov cx, 16000    ; Adjust for 2 pixels per byte format
        xor si, si
        xor di, di
        rep movsw
        pop ds
        pop es

    ; ======== DELAY ========
    delay_timer:
        mov ax, [TIMER]
        inc ax
        .wait:
            cmp [TIMER], ax
            jl .wait

jmp game_loop

; ======== DATA ========
.data:


; make boodsector
times 510 - ($ - $$) db 0  ; Pad remaining bytes to make 510 bytes
dw 0xAA55                  ; Boot signature at the end of 512 bytes