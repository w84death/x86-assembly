[bits 16]
[org 0x7c00]

start:
   
    mov ax, 0x00    ; Init segments
    mov ds, ax
    mov ax, 0xa000
    mov es, ax
    mov ax, 13h     ; Init VGA 
    int 10h

    ; Init game
    call draw_sky
    call draw_level

game_loop:
    ;call erease_player
    ;call wait_for_vertical_retrace
    call draw_sky
    call draw_level


    mov word ax, [player_pos]      ; Add x-coordinate
    add ax, 320*9
    cmp byte [mirror_direction], 0  ; Check direction
    jne shift_col_check
    dec ax                  
    jmp after_shift                  
    shift_col_check:
    add ax, 5
    after_shift:
    mov di, ax              ; Store in DI for ES:DI addressing
    
    mov ah, es:[di]         ; Check if platform
    cmp ah, PLATFORM_COLOR
    je run
    add word [player_pos], 320  ; Fall 1px down
    jmp continue_run

    run:
        call handle_keyboard
        
        ; Collision check
        mov ax, [player_pos]    ; Load the player's buffer position into AX
        mov cx, 320             ; Screen width into CX
        xor dx, dx              ; Clear DX to prevent errors in division
        div cx                  ; AX now contains quotient, DX contains remainder (player's x-coordinate)
        
        ; Check if the player's x-coordinate (DX) is at or beyond the left or right boundary
        cmp dx, 0               ; Check if at the left boundary
        je  swap_direction      ; Jump if exactly at the left edge
        cmp dx, 315             ; Check if at or beyond the right boundary (319 for a 320px wide screen)
        je  swap_direction     ; Jump if at or beyond the right edge
        
    check_run_dir:
        cmp byte [mirror_direction], 0
        je run_right
    run_left:
        dec word [player_pos]
        jmp continue_run
    run_right:
        inc word [player_pos]
        jmp continue_run
    swap_direction:
        xor byte [mirror_direction], 1  ; swap direction
        jmp check_run_dir
    continue_run:
        
    call draw_player
    call delay
    
   
jmp game_loop



delay:
    mov al, 0
    mov cx, 0
    mov dx, 12800
    mov ah, 86h
    int 15h
    ret

draw_sky:
    ; xor di,di
    ; mov al, SKY_COLOR
    ; mov cx, 320*170
    ; rep stosb

    ; mov al, GROUND_COLOR
    ; mov cx, 320*30
    ; rep stosb

    xor di,di           ; Reset buffer pos to 0
    mov cx, 5           ; Gradient levels
    draw_gradient:
    mov bx, SKY_COLOR    ; Sky starting color
    next_color:
        push cx                  ; Save outer loop counter
        mov cx, 40               ; Band size
        mov dx, 320
        mov al, bl
    draw_grad_line:
        push cx                  ; Save inner loop counter
        mov cx, dx               ; Set CX to 320 for rep stosb
        rep stosb
        pop cx
        loop draw_grad_line
        pop cx 
        dec bx
        loop next_color
    ret 

erease_player:
    mov word ax, [player_pos]     ; Add x-coordinate
    mov di, ax             ; Store in DI for ES:DI addressing
    
    mov cx, 8           ; Erease height 
    cmp byte [mirror_direction], 0
    je erease_line
    add di, 2
    erease_line:
        push cx             ; Save loop counter
        mov cx, 4           ; Erease width
        mov al, SKY_COLOR   ; Erease color
        rep stosb           ; Draw line
        add di, 316         ; 320-width
        pop cx          ; Restore loop counter
        loop erease_line
    ret

draw_player:
    mov bx, [current_frame]  ; Load current frame number

    mov ax, 32             ; Frame offset
    mul bx                 ; AX = 32 * current frame number
    mov si, sprite_data
    add si, ax             ; SI points to the start of the current frame data

    ; Calculate the starting address in video memory
    mov word ax, [player_pos]     ; Add x-coordinate
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
        inc byte [current_frame]
        cmp byte [current_frame], 3
        jl skip_reset
        mov byte [current_frame], 0
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

draw_level:
    lea si, [level_data] ; Point SI to the start of level data
read_segment:
    lodsw               ; Load pos
    test ax, ax
    jz done             ; If 0, end of data
    mov di, ax          ; DI now holds the start position
    lodsw               ; Load the length into AX
    mov bh, PLATFORM_COLOR
    
    mov cx, 4           ; Platform height  
    draw_platform:
        push cx         ; Save loop counter
        push ax         ; Save length
        mov cx, ax     
        mov al, bh
        add bh, 50
        rep stosb       ; Draw line
        
        pop ax        
        add di, 320
        sub di, ax      ; Move line down

        pop cx          ; Restore loop counter
        loop draw_platform

    jmp read_segment   ; Process next segment
done:
    ret                 ; Return from draw_level


.data:

player_pos dw 320*8+160
current_frame dw 0
mirror_direction db 0
SKY_COLOR equ 102
GROUND_COLOR equ 187
PLATFORM_COLOR equ 70
DELAY_MS equ 160

sprite_data:
    ; Dude - Frame 1 / 32b
    db SKY_COLOR, SKY_COLOR, SKY_COLOR, SKY_COLOR
    db SKY_COLOR, 0x2A, 0x2B, SKY_COLOR
    db 0x2A, 0x5A, 0x0F, SKY_COLOR
    db SKY_COLOR, 0x42, SKY_COLOR, SKY_COLOR
    db SKY_COLOR, 0x34, 0x35, SKY_COLOR
    db SKY_COLOR, 0x35, 0x34, SKY_COLOR
    db SKY_COLOR, 0x36, 0x36, SKY_COLOR
    db 0x36, SKY_COLOR, 0x37, SKY_COLOR
    ; Dude - Frame 2 / 32b
    db SKY_COLOR, SKY_COLOR, SKY_COLOR, SKY_COLOR
    db SKY_COLOR, 0x2A, 0x2B, SKY_COLOR
    db 0x2A, 0x5A, 0x0F, SKY_COLOR
    db SKY_COLOR, 0x42, SKY_COLOR, SKY_COLOR
    db SKY_COLOR, 0x34, 0x35, SKY_COLOR
    db SKY_COLOR, 0x34, 0x35, SKY_COLOR
    db SKY_COLOR, 0x36, 0x36, SKY_COLOR
    db SKY_COLOR, 0x36, 0x37, SKY_COLOR
    ; Dude - Frame 3 / 32b
    db SKY_COLOR, 0x2A, 0x2B, SKY_COLOR
    db 0x2A, 0x5A, 0x0F, SKY_COLOR
    db SKY_COLOR, 0x42, SKY_COLOR, SKY_COLOR
    db SKY_COLOR, 0x34, 0x35, SKY_COLOR
    db 0x34, 0x35, 0x35, SKY_COLOR
    db SKY_COLOR, 0x36, 0x36, SKY_COLOR
    db SKY_COLOR, 0x36, 0x37, 0x37
    db SKY_COLOR, 0x36, SKY_COLOR, SKY_COLOR
    ; Level building sprites


level_data: ;Structure: color, position in buffer, length of the platform
    dw 320*168, 320
    dw 320*10+10,50 
    dw 320*50+140,75
    dw 320*120,75
    dw 320*140+100,120
    dw 320*27+120,60
    dw 320*60+300, 10
    dw 320*130+200, 100
    dw 320*140+200, 20
    dw 320*160+240, 20
    db 0 ; End marker

; make boodsector
times 510 - ($ - $$) db 0  ; Pad remaining bytes to make 510 bytes
dw 0xAA55                  ; Boot signature at the end of 512 bytes

; make floppy
; times 1474560 - ($ - $$) db 0