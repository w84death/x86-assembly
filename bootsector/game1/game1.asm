[bits 16]
[org 0x7c00]

; ======== SETTINGS ========

BUFFER equ 0x1000
TIMER equ 046Ch
PLAYER_COLOR equ 34
SKY_COLOR equ 82
PLATFORM_COLOR equ 39
BOAT_COLOR equ 53
BOAT_POSITION equ 320*187+120
BOAT_WIDTH equ 80
BOAT_HEIGHT equ 3
SPRITE_SIZE equ 14
DEATH_ROW equ 198
TIMER equ 046Ch
PLAYER_START equ 320*6+150
LEVEL_SIZE equ 5
PLATFORM_HEIGHT equ 6
LEVELS equ 4

; ======== GRAPHICS INITIALIZATION ========

start:
    mov ax, 0x0000    ; Init segments
    mov ds, ax
    mov ax, 0xA000
    mov es, ax
    mov ax, 13h     ; Init VGA 
    int 10h
    
    mov ax, BUFFER
    mov es, ax

; ======== GAME RESTART ========

restart_game:
    mov word [player_pos], PLAYER_START
    mov word [current_level], 0
    xor word [mirror_direction], 1
    mov word [boat_anim], 0
    mov byte [sky], SKY_COLOR
    jmp game_loop

; ======== NEXT LEVEL ========

next_level:
    inc word [current_level]
    mov word ax, [current_level]
    cmp ax, LEVELS
    je restart_game
    mov word [player_pos], PLAYER_START
    mov word [boat_anim], 0
    add byte [sky], 64

; ======== GAME LOOP  ========

game_loop:

    ; ======== DRAW SKY ========

    draw_sky:
        xor di,di           ; Reset buffer pos to 0
        mov cx, 10           ; Gradient levels
        .draw_gradient:
        mov bx, [sky]    ; Sky starting color
        .next_color:
            push cx                  ; Save outer loop counter
            mov cx, 20               ; Band size
            mov dx, 320
            add bl, 2
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

    ; ======== DRAW OCEAN ========

    draw_ocean:
        sub di, 320*20
        mov cx, 20
        mov bl, 52
        .draw_row:
            push cx
            mov cx, 320 
            xor bl, 4
            mov al, bl
            mov dx, 320
            rep stosb
        pop cx
        loop .draw_row

    ; ======== DRAW LEVEL ========

    draw_level:
        xor di, di
        mov bx, [current_level]
        mov ax, LEVEL_SIZE
        mul bx
        mov si, level_data
        add si, ax              ; Move to correct level
    
        ; ======== BOAT ========

        mov bh, BOAT_COLOR      ; Draw boat platform
        mov ax, BOAT_POSITION
        add ax, [boat_anim]
        add di, ax
        mov cx, BOAT_HEIGHT
        mov ax, BOAT_WIDTH
        jmp .draw_platform

    .read_next_platform:
        lodsb                   ; Load pos
        test ax, ax
        jz done                 ; If 0, end of data
        movzx ax, al            ; Zero-extend AL to AX for multiplication (x value)
        imul ax, 20             ; Fit to grid
        mov bx, ax              ; Store result in BX temporarily
        movzx ax, ah            ; Zero-extend AH to AX for multiplication (y value)
        imul ax, 10             ; Fit to grid
        imul ax, 320          
        add ax, bx              ; AX = final offset in the framebuffer
        mov di, ax              ; Move calculated offset into DI
        mov ax, [current_level] ; Width of platform
        add ax, 2               ; Current level + 2
        imul ax, 20             ; Fit to grid
        mov bh, PLATFORM_COLOR
        mov cx, PLATFORM_HEIGHT  
        .draw_platform:
            push cx         ; Save loop counter
            push ax         ; Save length
            mov cx, ax     
            mov al, bh
            inc bh          ; move color
            rep stosb       ; Draw line
            pop ax  
            add di, 319       
            sub ax, 2
            sub di, ax
            pop cx          ; Restore loop counter
            loop .draw_platform
        jmp .read_next_platform   ; Process next segment
    done:

; ======== ANIMATE BOAT ========

    animate_boat:
        cmp byte [boat_direction], 0
        jnz .sail_left
        .sail_right:
            add word [boat_anim], 2
            jmp .done
        .sail_left:
            sub word [boat_anim], 2
            cmp word [boat_anim], -80
            jz .reverse
        .done:
        cmp byte [boat_anim], 80
        jl collision_check
        .reverse:
        xor byte [boat_direction], 1

; ======== COLLISION CHECKING ========

 collision_check:
        mov bx, SPRITE_SIZE
        add ax, 320                     ; Check below sprite top pos
        mul bx
        add word ax, [player_pos]       ; Add x-coordinate
        cmp ax, 320*DEATH_ROW           ; Check if drop to the ocean
        ja  restart_game 
        mov di, ax                      ; Store in DI for ES:DI addressing
        sub di, SPRITE_SIZE/2
        mov cx, SPRITE_SIZE
        .chk:
            mov ah, es:[di]             ; Check if platform
            cmp ah, PLATFORM_COLOR
            je restart_game
            cmp ah, BOAT_COLOR
            je next_level
            inc di
        loop .chk
        
        add word [player_pos], 320      ; Fall 1px down
        
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

    ; ======== DRAW PLAYER ========
    draw_player:
        mov word ax, [player_pos]     ; Add x-coordinate
        mov di, ax             ; Store in DI for ES:DI addressing
        push di
        mov bh, PLAYER_COLOR
        xor ax, ax
        mov cx, SPRITE_SIZE
        .draw_row:
            push cx         ; Save loop counter
            push ax         ; Save length
            
            mov cx, ax     
            mov al, bh
            rep stosb
            pop ax
            cmp ax, SPRITE_SIZE/2
            jge .skip_enlarge
            add di, 321       
            add ax, 2
            jmp .finish_row
            .skip_enlarge:
            dec bh
            add di, 320
            .finish_row:
            sub di, ax      ; Move line down 
            pop cx          ; Restore loop counter
            loop .draw_row

            .eyes:
                pop di
                add di, 320*SPRITE_SIZE/2-2
                xor al, al
                push cx
                mov cx, 4
                rep stosb
                xor di, 2
                inc cx
                sub di, 3
                mov cx, 2
                rep stosb

    ; ======== KEYBOARD ========

    .handle_keyboard:
        mov ah, 0x01            ; Check if a key has been pressed
        int 0x16
        jz .no_kb               ; Jump if no key is in the keyboard buffer
        xor ax,ax            ; Get the key press
        int 0x16
        
        ; REMOVE ME
        ; cmp ah, 0x01            ; Check if the scan code is for the [Esc] key
        ; je  restart_game
        ; cmp ah, 0x1C            ; Check if the scan code is for the [Esc] key
        ; je  next_level
        ; /REMOVE ME

        sub word [player_pos], 320
        xor byte [mirror_direction], 1  ; swap direction

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
player_pos dw 0
mirror_direction db 0
current_level dw 0
boat_anim dw 0
boat_direction db 0
sky db SKY_COLOR

; ======== LEVELS ========

level_data: ; 5b
    db 73
    db 85
    db 121
    db 149
    db 0    ; End of level
level_2:
    db 56
    db 106
    db 117
    db 184
    db 0    ; End of level
level_3:
    db 57
    db 101
    db 168
    db 195
    db 0    ; End of level
level_4:
    db 87    
    db 119
    db 129
    db 176
    db 198
    db 203   ; Continue read positions from P1X 80,50,88...

; ======== BOOTSECTOR  ========

times 506 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X', 0            ; P1X signature 4b
dw 0xAA55                  ; Boot signature at the end of 512 bytes