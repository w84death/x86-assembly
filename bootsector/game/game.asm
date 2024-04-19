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
    mov word [player_pos], PLAYER_START
    mov word [current_level], 0
    mov word [mirror_direction], 0
    mov word [anim], 0
    jmp game_loop

next_level:
    mov word ax, [current_level]
    cmp ax, 3
    jl .inc_level
        mov word [current_level], 0
    .inc_level:
        add word [current_level], 1
    mov word [player_pos], PLAYER_START
    mov word [anim], 0

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
        mov bx, [current_level]
        mov ax, LEVEL_SIZE
        mul bx
        mov si, level_data
        add si, ax              ; Move to correct level
    
    mov byte [exit], 0
    .read_segment:
        lodsb               ; Load pos
        test ax, ax
        jz done             ; If 0, end of data

        movzx ax, al          ; Zero-extend AL to AX for multiplication (x value)
        imul ax, 20           ; AX = x * 20
        mov bx, ax            ; Store x*20 result in BX temporarily

        movzx ax, ah          ; Zero-extend AH to AX for multiplication (y value)
        imul ax, 10           ; AX = y * 20
        imul ax, 320          ; AX = y * 20 * 320 (Y offset in a linear frame buffer)
        add ax, 6400
        add ax, bx            ; AX = final offset in the framebuffer
        mov di, ax            ; Move calculated offset into DI
        lodsb
        movzx ax, al
        imul ax, 20             ; width of platform

        mov bh, PLATFORM_COLOR
        push ax
            mov ax, [exit]
            cmp ax, 0
            jne  .normal_platform
            mov bh, EXIT_COLOR
            mov ax, [anim]
            add di, ax
            .normal_platform:
        pop ax
        
        mov cx, 8           ; Platform height  
        .draw_platform:
            push cx         ; Save loop counter
            push ax         ; Save length
            cmp ax, 2
            jle .skip_draw_line
            mov cx, ax     
            mov al, bh
            add bh, 24
            rep stosb       ; Draw line

            .skip_draw_line:
            pop ax  
            add di, 318       
            sub ax, 4
            sub di, ax      ; Move line down
            pop cx          ; Restore loop counter
            loop .draw_platform

        inc byte [exit]

        jmp .read_segment   ; Process next segment
    done:
    
    ; mov bx, [anim]
    ; cmp bx, 320*12          ; Exit drifted too much
    ; jl next_frame
    ; mov word [anim], 0
    ; next_frame:
    inc word [anim]

    collision_check:
        push cx
        mov bx, SPRITE_SIZE
        add ax, 320                   ; check below sprite top pos
        mul bx
        add word ax, [player_pos]      ; Add x-coordinate

        cmp ax, 320*DEATH_ROW
        ja  restart_game 

        cmp byte [mirror_direction], 0  ; Check direction
        jne .shift_col_check
        sub ax, SPRITE_SIZE/2                 
        jmp .after_shift                  
        .shift_col_check:
        add ax, SPRITE_SIZE/2
        .after_shift:
        mov di, ax              ; Store in DI for ES:DI addressing
        mov ah, es:[di]         ; Check if platform
        cmp ah, PLATFORM_COLOR
        jna run
        cmp ah, EXIT_COLOR
        ja next_level
        
        add word [player_pos], 320  ; Fall 1px down
        
        jmp run.continue_run
    run:
        .check_run_dir:
            cmp byte [mirror_direction], 0
            je .run_right
        .run_left:
            dec word [player_pos]
            jmp .continue_run
        .run_right:
            inc word [player_pos]
        .continue_run:
        
    .handle_keyboard:
        mov ah, 0x01            ; Check if a key has been pressed
        int 0x16
        jz .no_kb                ; Jump if no key is in the keyboard buffer
        mov ah, 0x00            ; Get the key press
        int 0x16
        cmp ah, 0x01            ; Check if the scan code is for the [Esc] key
        je  restart_game
        cmp ah, 0x1C            ; Check if the scan code is for the [Esc] key
        je  next_level

        xor byte [mirror_direction], 1  ; swap direction
        sub word [player_pos], 320*2
    .no_kb:

    draw_player:
        mov word ax, [player_pos]     ; Add x-coordinate
        mov di, ax             ; Store in DI for ES:DI addressing

        mov bh, PLAYER_COLOR
        mov ax, 1
        mov cx, SPRITE_SIZE
        .draw_row:
            push cx         ; Save loop counter
            push ax         ; Save length
            
            mov cx, ax     
            mov al, bh
            add bh, 1
            rep stosb
            pop ax
            cmp ax, SPRITE_SIZE/2
            jge .skip_enlarge
            add di, 321       
            add ax, 2
            
            jmp .finish_row
            .skip_enlarge:
            add di, 320
            .finish_row:
            sub di, ax      ; Move line down 
            pop cx          ; Restore loop counter
            loop .draw_row
        .drawDir:
            mov ax, 320*7
            sub di, ax      ; Move up 4 lines
            mov ax, -2
            cmp byte [mirror_direction], 0  ; Check direction
            jne .shifted
            mov ax, 5
            .shifted:
            add di, ax  ; Move position left/right
            mov cx, 4
            mov al, 128
            rep stosb 

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
mirror_direction db 0
current_level dw 0
exit dw 0
anim dw 0
PLAYER_COLOR equ 53
SKY_COLOR equ 82
PLATFORM_COLOR equ 71
EXIT_COLOR equ 98
SPRITE_SIZE equ 12
DEATH_ROW equ 198
TIMER equ 046Ch
PLAYER_START equ 320*6+150
LEVEL_SIZE equ 14

level_data: ; 20b
    db 202, 6
    db 23, 3
    db 83, 8
    db 136, 6
    db 166, 3
    db 0, 0 ; End marker
    db 0, 0
level_2: ; 20b
    db 201, 4
    db 23, 2
    db 54, 4
    db 82, 4
    db 91, 2
    db 134,5
    db 0, 0 ; End marker
level_3:
    db 200, 2
    db 39, 3
    db 133, 2
    db 0, 0
    db 0, 0
    db 0, 0
    db 0, 0 ; End marker
level_4:
    db 204, 1
    db 39, 1
    db 86, 1
    db 137, 2
    db 167, 2
    db 0, 0 ; End marker

; make boodsector
times 510 - ($ - $$) db 0  ; Pad remaining bytes to make 510 bytes
dw 0xAA55                  ; Boot signature at the end of 512 bytes

; make floppy
; times 1474560 - ($ - $$) db 0