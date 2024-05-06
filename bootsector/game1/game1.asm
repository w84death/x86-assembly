; GAME 1 - Land Me
; by Krzysztof Krystian Jankowski ^ P1X
;

[bits 16]
[org 0x7c00]

; ======== MEMORY POINTERS ========
VGA equ 0xA000
TIMER equ 046Ch
BUFFER equ 0x1000       ; 64000
MEM_BASE equ 0x7e00
MEM_SKY equ MEM_BASE   ; 2 
MEM_MIRROR equ MEM_BASE+2   ; 32 
MEM_PLAYER_POS equ MEM_BASE+4
MEM_CURRENT_LEVEL equ MEM_BASE+6
MEM_BOAT_ANIM equ MEM_BASE+8
MEM_BOAT_DIR equ MEM_BASE+10
MEM_LIFES equ MEM_BASE+12

; ======== SETTINGS ========
PLAYER_COLOR equ 31
SKY_COLOR equ 82
PLATFORM_COLOR equ 39
BOAT_COLOR equ 53
BOAT_POSITION equ 320*187+120
BOAT_WIDTH equ 80
BOAT_HEIGHT equ 3
SPRITE_SIZE equ 14
DEATH_ROW equ 198
PLAYER_START equ 320*6+150
LEVEL_SIZE equ 5
PLATFORM_HEIGHT equ 6
LEVELS equ 3

; ======== GRAPHICS INITIALIZATION ========

start:
    xor ax,ax       ; Init segments (0)
    mov ds, ax
    mov ax, VGA     ; Set VGA memory
    mov es, ax      ; as target
    mov ax, 13h     ; Init VGA 
    int 10h
    
    mov ax, BUFFER  ; Set double buffer
    mov es, ax      ; as target

; ======== GAME RESTART ========

restart_game:
    mov word [MEM_PLAYER_POS], PLAYER_START
    cmp byte [MEM_LIFES], 0
    jz .game_over

    .restart_player:
    dec byte [MEM_LIFES]
    jmp game_loop

    .game_over:
    mov word [MEM_CURRENT_LEVEL],0
    xor word [MEM_MIRROR], 1
    mov word [MEM_BOAT_ANIM], 0
    mov byte [MEM_SKY], SKY_COLOR
    mov byte [MEM_LIFES], 3
    jmp game_loop

; ======== NEXT LEVEL ========

next_level:
    cmp word [MEM_CURRENT_LEVEL], LEVELS
    ja restart_game
    inc word [MEM_CURRENT_LEVEL]
    mov word [MEM_PLAYER_POS], PLAYER_START
    mov word [MEM_BOAT_ANIM], 0
    add byte [MEM_SKY], 64

; ======== GAME LOOP  ========

game_loop:

    ; ======== DRAW MEM_SKY ========

    draw_bg:
    xor di, di              ; Reset DI
    mov cx, 200   ; Repeat for full screen height
    
    .draw_line:
                            ; Decide on start color
    mov bx, [MEM_SKY]       ; Set color to MEM_SKY
    mov ax, cx              ; Copy line number to AX
    and ax, 0xFF            ; Clear all but 0xFF
    shr ax, 4               ; Shift 4 times = div by 16 (200/16 = 12px band)
    add bx, ax              ; Shift current color intex (BX)
                            ; Drawing
    push cx                 ; Save loop counter
    mov al, bl              ; Set color (from BX)
    mov cx, 320    ; Set length (full screen width line)
    rep stosb               ; Send colors to frame buffer
    pop cx                  ; Load loop counter
    loop .draw_line


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


; ======== DRAW LIFES ========

    xor di, di
    add di, 320+80
    mov bx, 0
    mov cx, [MEM_LIFES]
    inc cx
    draw_life:
        push cx
        mov al, 12
        mov cx, 40    ; Set length (full screen width line)
        rep stosb     ; Send colors to frame buffer
        pop cx
        loop draw_life

    ; ======== DRAW LEVEL ========

    draw_level:
        xor di, di
        mov bx, [MEM_CURRENT_LEVEL]
        mov ax, LEVEL_SIZE
        mul bx
        mov si, level_data
        add si, ax              ; Move to correct level
    
        ; ======== BOAT ========

        mov bh, BOAT_COLOR      ; Draw boat platform
        mov ax, BOAT_POSITION
        add ax, [MEM_BOAT_ANIM]
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
        mov ax, [MEM_CURRENT_LEVEL] ; Width of platform
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
        cmp byte [MEM_BOAT_DIR], 0
        jnz .sail_left
        .sail_right:
            add word [MEM_BOAT_ANIM], 2
            jmp .done
        .sail_left:
            sub word [MEM_BOAT_ANIM], 2
            cmp word [MEM_BOAT_ANIM], -80
            jz .reverse
        .done:
        cmp byte [MEM_BOAT_ANIM], 80
        jl collision_check
        .reverse:
        xor byte [MEM_BOAT_DIR], 1



; ======== COLLISION CHECKING ========

 collision_check:
        mov bx, SPRITE_SIZE
        add ax, 320                     ; Check below sprite top pos
        mul bx
        add word ax, [MEM_PLAYER_POS]       ; Add x-coordinate
        cmp ax, 320*DEATH_ROW           ; Check if drop to the ocean
        ja  restart_game 
        mov di, ax                      ; Store in DI for ES:DI addressing
        sub di, SPRITE_SIZE/2
        mov cx, SPRITE_SIZE
        .chk:
            mov ah, [es:di]
            cmp ah, PLATFORM_COLOR
            je restart_game
            cmp ah, BOAT_COLOR
            je next_level
            inc di
        loop .chk
        
        add word [MEM_PLAYER_POS], 320      ; Fall 1px down
        
    run:
        .check_run_dir:
            cmp byte [MEM_MIRROR], 0
            je .run_right
        .run_left:
            dec word [MEM_PLAYER_POS]
            jmp .continue_run
        .run_right:
            inc word [MEM_PLAYER_POS]
        .continue_run:

    ; ======== DRAW PLAYER ========
    draw_player:
        mov word ax, [MEM_PLAYER_POS]     ; Add x-coordinate
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

        sub word [MEM_PLAYER_POS], 320
        xor byte [MEM_MIRROR], 1  ; swap direction

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
    db 132      ; Continue read positions from P1X 80,50,88...
    db 'P1X'    ; P1X signature 3b
    db 0
; ======== BOOTSECTOR  ========
TIMES 510 - ($ - $$) DB 0 ; Fill empty space (512) - signatures (5b)
DW 0xAA55 ; Bootsector 2b