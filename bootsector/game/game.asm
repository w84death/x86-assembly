[bits 16]
[org 0x7c00]

BUFFER equ 0x1000

start:
    mov ax, 0x0000    ; Init segments
    mov ds, ax
    mov ax, 0xA000
    mov es, ax
    mov ax, 13h     ; Init VGA 
    int 10h
    mov ax, BUFFER
    mov es, ax

restart_game:
    mov word [player_pos], 320*6+160

    ; mov ax, [CS:TIMER]
    ; and ax, 100

    ; cmp ax, 20
    ; jle game_loop

    ; mov word [platform_size], ax
    ; add word [platform_shift], ax

game_loop:

    draw_sky:
        xor di,di           ; Reset buffer pos to 0
        mov cx, 10           ; Gradient levels
        .draw_gradient:
        mov bx, SKY_COLOR    ; Sky starting color
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
            dec bx
            loop .next_color

    draw_level:
    lea si, [level_data] ; Point SI to the start of level data
    .read_segment:
        lodsw               ; Load pos
        test ax, ax
        jz done             ; If 0, end of data
        mov di, ax          ; DI now holds the start position
        lodsw               ; Load the length into AX
        mov bh, PLATFORM_COLOR
        
        mov cx, 10           ; Platform height  
        .draw_platform:
            push cx         ; Save loop counter
            push ax         ; Save length
            cmp ax, 2
            jle .skip_draw_line
            mov cx, ax     
            mov al, bh
            add bh, 50
            rep stosb       ; Draw line

            .skip_draw_line:
            pop ax  
            add di, 319       
            sub ax, 2
            sub di, ax      ; Move line down
            pop cx          ; Restore loop counter
            loop .draw_platform
        jmp .read_segment   ; Process next segment
    done:
    
    collision_check:
        mov bx, SPRITE_HEIGHT
        sub bx, 1
        add ax, 320                   ; check 6px below sprite top pos
        mul bx
        add word ax, [player_pos]      ; Add x-coordinate

        cmp ax, 320*DEATH_ROW
        ja  restart_game 

        cmp byte [mirror_direction], 0  ; Check direction
        jne .shift_col_check
        add ax, 2                 
        jmp .after_shift                  
        .shift_col_check:
        add ax, 2
        .after_shift:
        mov di, ax              ; Store in DI for ES:DI addressing
        mov ah, es:[di]         ; Check if platform
        cmp ah, PLATFORM_COLOR
        je run
        add word [player_pos], 320*2  ; Fall 1px down
        jmp run.continue_run

    run:       
        mov ax, [player_pos]    ; Load the player's buffer position into AX
        mov cx, 320             ; Screen width into CX
        xor dx, dx              ; Clear DX to prevent errors in division
        div cx                  ; AX now contains quotient, DX contains remainder (player's x-coordinate)

        cmp dx, 2               ; Check if at the left boundary
        je  .swap_direction      ; Jump if exactly at the left edge
        cmp dx, 319 - SPRITE_WIDTH            ; Check if at or beyond the right boundary (319 for a 320px wide screen)
        je  .swap_direction     ; Jump if at or beyond the right edge
       
        .check_run_dir:
            cmp byte [mirror_direction], 0
            je .run_right
        .run_left:
            dec word [player_pos]
            jmp .continue_run
        .run_right:
            inc word [player_pos]
            jmp .continue_run
        .swap_direction:
            xor byte [mirror_direction], 1  ; swap direction
            jmp .check_run_dir
        .continue_run:
        
    .handle_keyboard:
        mov ah, 0x01            ; Check if a key has been pressed
        int 0x16
        jz .no_kb                ; Jump if no key is in the keyboard buffer
        mov ah, 0x00            ; Get the key press
        int 0x16
        cmp ah, 0x01            ; Check if the scan code is for the [Esc] key
        je  restart_game

        xor byte [mirror_direction], 1  ; swap direction
    .no_kb:

    draw_player:
        mov bx, [current_frame]  ; Load current frame number

        mov ax, 28             ; Frame offset
        mul bx                 ; AX = 28 * current frame number
        mov si, sprite_data
        add si, ax             ; SI points to the start of the current frame data

        ; Calculate the starting address in video memory
        mov word ax, [player_pos]     ; Add x-coordinate
        mov di, ax             ; Store in DI for ES:DI addressing
    
    ; Check mirror direction
        cmp byte [mirror_direction], 0
        je draw_normal
        add di, 4
        mov cx, SPRITE_HEIGHT
        draw_mirrored:
            push cx
            ; lea bx, [si+SPRITE_WIDTH-1]
            mov cx, SPRITE_WIDTH
            push di             ; Save DI before drawing each row
            .draw_pixel:
                push cx
                lodsb
                test al, al
                jz .skip_pixel
                stosb
                jmp .continue_pixel
                .skip_pixel:
                    inc di 
                .continue_pixel:
                    add di, -2
                pop cx
            loop .draw_pixel
            pop di              ; Restore DI from the saved value before drawing each row
            add di, 320        ; Move DI to the start of the next line
            pop cx
            loop draw_mirrored
        jmp finish_draw

        draw_normal:
            mov cx, SPRITE_HEIGHT
            .draw_row:
                push cx
                mov cx, SPRITE_WIDTH
                .draw_pixel:
                    push cx
                    lodsb
                    test al, al
                    jz .skip_pixel
                    stosb
                    jmp .continue_pixel
                    .skip_pixel:
                        inc di
                    .continue_pixel:
                    pop cx
                    loop .draw_pixel
                pop cx
                add di, 320 - SPRITE_WIDTH         ; Move DI to the start of the next line
                loop .draw_row

    finish_draw:
        inc byte [current_frame]
        cmp byte [current_frame], 3
        jl .skip_reset
        mov byte [current_frame], 0
        .skip_reset:

    vga_blit:
        push es
        push ds
        mov ax, 0xA000  ; VGA memory
        mov bx, BUFFER  ; Buffer memory
        mov es, ax
        mov ds, bx
        mov cx, 32000   ; Half of the buffer
        ; cld
        xor si, si
        xor di, di
        rep movsw
        pop ds
        pop es

    delay_timer:
        mov ax, [TIMER]
        inc ax
        .wait:
            cmp [TIMER], ax
            jl .wait

jmp game_loop

.data:
player_pos dw 0
current_frame dw 0
mirror_direction db 0
platform_size dw 200
platform_shift dw 0
SKY_COLOR equ 82
PLATFORM_COLOR equ 70
SPRITE_WIDTH equ 4
SPRITE_HEIGHT equ 7
DEATH_ROW equ 194
TIMER equ 046Ch

sprite_data:
    ; Girl - Frame 1 / 28b
    db 0, 0, 0, 0, 0, 
    db 42, 42, 0
    db 42, 90, 15, 0
    db 0, 88, 0, 0
    db 0, 59, 83, 0
    db 0, 59, 34, 0
    db 33,0,32,0
    ; Girl - Frame 2 / 28b
    db 0, 42, 42, 0
    db 42, 90, 15, 0
    db 0, 88, 0, 0
    db 0, 59, 83, 0
    db 0, 59, 34, 0
    db 0,55,55,33
    db 0,32,0,0
    ; Girl - Frame 3 / 28b
    db 42, 42, 42, 0
    db 0, 90, 15, 0
    db 0, 88, 0, 0
    db 0, 59, 83, 0
    db 0, 59, 34, 0
    db 0,55,55,0
    db 0,33,32,0

level_data: ;Structure: position in buffer, length of the platform // 40b
    dw 320*168+60, 200
    dw 320*10+10,50 
    dw 320*50+140,75
    dw 320*120,75
    dw 320*140+100,120
    dw 320*26+120,60
    dw 320*60+300, 10
    dw 320*130+190, 60
    dw 320*140+200, 20
    dw 320*154+240, 20
    db 0,0 ; End marker

; make boodsector
times 510 - ($ - $$) db 0  ; Pad remaining bytes to make 510 bytes
dw 0xAA55                  ; Boot signature at the end of 512 bytes

; make floppy
; times 1474560 - ($ - $$) db 0