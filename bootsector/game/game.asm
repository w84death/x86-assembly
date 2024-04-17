org 0x7c00

start:
    mov ax, 0x00
    mov ds, ax
    mov ax, 0xa000
    mov es, ax

    mov ax, 0x0013  ; VGA
    int 0x10

    ; draw background

    mov al, 0x66    ; sky
    mov cx, 320*180
    xor di,di
    rep stosb

    mov bx, 180    ; y position
    mov ax, 320    ; screen width
    mul bx         ; memory position (y*width)
    mov di, ax     ; destination index in video memory
    mov cx, 320    ; number of pixels in one line
    
    mov al, 0xa   ; grass
    rep stosb

    mov al, 0x76    ; ground
    mov cx, 320*20
    rep stosb

demoloop:
    ; clear screen - TODO: clear only behind player
    mov al, 0x66
    mov cx, 320*10
    add cx, 320*170 ; clear 170-180 lines
    xor di,di
    rep stosb

    call draw_player
    call handle_keyboard

    cmp word [player_y], 172
    je run
    add word [player_y], 5
    jmp no_run

    run:
    cmp byte [mirror_direction], 0
    je run_right

    run_left:
        cmp word [player_x], 0
        je swap_direction
        dec word [player_x]
        jmp no_run
    
    run_right:
        cmp word [player_x], 316
        je swap_direction
        inc word [player_x]
        jmp no_run

        swap_direction:
        xor byte [mirror_direction], 1  ; swap direction
    no_run:
        call simple_delay
    

jmp demoloop

simple_delay:
    push ax   ; Save AX register
    push cx   ; Save CX register

outer_loop:
    mov cx, 0x00AF  ; Set the inner loop counter to its maximum value for maximum delay

inner_loop:
    dec cx          ; Decrement CX
    jnz inner_loop  ; Continue inner loop until CX is zero

    dec dx          ; Decrement DX
    jnz outer_loop  ; Continue outer loop until DX is zero

    pop cx          ; Restore CX register
    pop ax          ; Restore AX register
    ret             ; Return from the function

draw_player:

    mov bx, [current_frame]  ; Load current frame number

    mov ax, 32             ; Calculate frame offset (each frame is 32 bytes in the sprite data)
    mul bx                 ; AX = 32 * current frame number
    mov si, sprite_data
    add si, ax             ; SI points to the start of the current frame data

    ; Calculate the starting address in video memory
    mov ax, 320            ; Screen width
    mul word [player_y]    ; y-coordinate
    add ax, [player_x]     ; Add x-coordinate
    mov di, ax             ; Store in DI for ES:DI addressing
   
   ; Check mirror direction
    cmp byte [mirror_direction], 0
    je draw_normal

    ; Draw mirrored sprite
    mov cx, 8          ; 8 rows
    add di, 4           ; shift sprite to the right
    draw_mirrored_row:
        push cx
        mov cx, 4           ; 4 pixels per row
        lea bx, [si+3]      ; Start from the end of the row in sprite data
        push di             ; Save DI before drawing each row
        mirror_pixel_loop:
            lodsb           ; Load byte from SI into AL, decrementing SI
            stosb           ; Store byte from AL into DI, incrementing DI
            add di, -2      ; Move DI back two places (to correct the forward increment from stosb)
        loop mirror_pixel_loop
        pop di              ; Restore DI from the saved value before drawing each row
        add di, 320         ; Move DI to the start of the next line
        pop cx
        loop draw_mirrored_row
        jmp finish_draw

    draw_normal:
    ; Draw the sprite frame normally
    mov cx, 8              ; 8 rows
    draw_sprite_row:
        push cx
        mov cx, 4           ; 4 pixels per row
        rep movsb           ; Move sprite row to video memory
        pop cx
        add di, 316         ; Move DI to the start of the next line (320 - 4)
        loop draw_sprite_row

    finish_draw:
        inc word [current_frame]
        cmp word [current_frame], 3
        jl skip_reset
        mov word [current_frame], 0
    skip_reset:
    ret

handle_keyboard:
        mov ah, 0x01            ; Check if a key has been pressed
        int 0x16
        jz no_kb                ; Jump if no key is in the keyboard buffer

        mov ah, 0x00            ; Get the key press
        int 0x16
        xor byte [mirror_direction], 1  ; swap direction
        
    no_kb:
        ret

.data:
player_x dw 160
player_y dw 12
current_frame dw 0
mirror_direction dw 0

sprite_data:
    ; Dude - Frame 1
    db 0x66, 0x66, 0x66, 0x66
    db 0x66, 0x2A, 0x2B, 0x66
    db 0x2A, 0x5A, 0x0F, 0x66
    db 0x66, 0x42, 0x66, 0x66
    db 0x66, 0x34, 0x35, 0x66
    db 0x66, 0x35, 0x34, 0x66
    db 0x66, 0x36, 0x36, 0x66
    db 0x36, 0x66, 0x37, 0x66
    ; Dude - Frame 2
    db 0x66, 0x66, 0x66, 0x66
    db 0x66, 0x2A, 0x2B, 0x66
    db 0x2A, 0x5A, 0x0F, 0x66
    db 0x66, 0x42, 0x66, 0x66
    db 0x66, 0x34, 0x35, 0x66
    db 0x66, 0x34, 0x35, 0x66
    db 0x66, 0x36, 0x36, 0x66
    db 0x66, 0x36, 0x37, 0x66
    ; Dude - Frame 4
    db 0x66, 0x2A, 0x2B, 0x66
    db 0x2A, 0x5A, 0x0F, 0x66
    db 0x66, 0x42, 0x66, 0x66
    db 0x66, 0x34, 0x35, 0x66
    db 0x34, 0x35, 0x35, 0x66
    db 0x66, 0x36, 0x36, 0x66
    db 0x66, 0x36, 0x37, 0x37
    db 0x66, 0x36, 0x66, 0x66


; make boodsector
times 510 - ($ - $$) db 0  ; Pad remaining bytes to make 510 bytes
dw 0xAA55                  ; Boot signature at the end of 512 bytes

; make floppy
; times 1474560 - ($ - $$) db 0