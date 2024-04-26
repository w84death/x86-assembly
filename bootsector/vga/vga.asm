[bits 16]
[org 0x7c00]

; ======== CONSTS ========
BUFFER equ 0x1000
TIMER equ 046Ch

; ======== GRAPHICS INITIALIZATION ========
start:
    push 0x0000    ; Init segments
    pop es
    mov ax, 13h     ; Init VGA 
    int 10h
    
    push BUFFER
    pop es

; ======== GAME RESTART ========
restart_game:


; ======== GAME LOOP  ========
game_loop:

    ; ======== TEST DRAW ========

    xor di,di           ; Reset buffer pos to 0
    mov cx, 10           ; Gradient levels
    .draw_gradient:
    mov bx, 0    ; Sky starting color
    .next_color:
        push cx                  ; Save outer loop counter
        mov cx, 20               ; Band size
        mov dx, 320
        mov al, bl
    .draw_grad_line:
        push cx                  ; Save inner loop counter
        mov cx, dx               ; Set CX to 320 for rep stosb
        rep stosb
        pop cx
        loop .draw_grad_line
        pop cx 
        inc bx                    ; Next color
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
        mov ax, 0xA000  ; VGA memory
        mov bx, BUFFER  ; Buffer memory
        mov es, ax
        mov ds, bx
        mov cx, 32000   ; Half of the buffer
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