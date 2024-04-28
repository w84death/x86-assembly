[bits 16]
[org 0x7c00]

; ======== MEMORY MAP ========

TIMER equ 0x046C                ; BIOS timer
MEM_BASE equ 0x1000
LIFE equ MEM_BASE               ; 1 byte
LEVEL equ MEM_BASE+1
PIXEL_MASK equ MEM_BASE+2       ; 2 bytes
SPRITE_POS equ MEM_BASE+4       ; 2 bytes
SPRITE_COLOR equ MEM_BASE+8     ; 1 byte
PLAYER_POS equ MEM_BASE+10      ; 2 bytes
ENEMIES equ MEM_BASE+12

; ======== SETTINGS ========

SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200
SPRITE_SIZE equ 8
COLOR_BG equ 20
COLOR_GRASS equ 3*16+4
PLAYER_START_POS equ 320*96+16
ENEMY_START_POS equ 320*30+300

; ======== GRAPHICS INITIALIZATION ========

start:
    xor ax,ax    ; Init segments
    mov ds, ax
    mov ax, 0xA000
    mov es, ax
    mov ax, 13h     ; Init VGA 
    int 10h

; ======== GAME RESET/INIT ========

game_reset:
mov byte [LIFE], 16
mov byte [LEVEL], 1
mov word [PIXEL_MASK], 0x8000
mov word [PLAYER_POS], PLAYER_START_POS
mov word [ENEMIES], ENEMY_START_POS



redraw_screen:
; ======== DRAWING SKY / GROUND ========

draw_bg:
    xor di, di                  ; Reset DI
    mov cx, SCREEN_WIDTH*SCREEN_HEIGHT    ; Repeat 125 lines
    mov al, COLOR_BG           ; Set color to sky
    rep stosb                   ; Push line to screen buffer

compose_level:
    mov word ax, [PLAYER_POS]
    mov word [SPRITE_POS], ax
    mov bx, sprite_test
    mov byte [SPRITE_COLOR], COLOR_GRASS
    call draw_sprite

    mov word ax, [ENEMIES]
    mov word [SPRITE_POS], ax
    mov bx, start
    mov cx, 4
    .l:
        push cx
        
        add bx, 8
        mov byte [SPRITE_COLOR], 44
        mov ax, 320*8
        imul ax, cx
        add word [SPRITE_POS], ax
        
        call draw_sprite
        pop CX
    loop .l
; ======== GAME LOOP  ========

game_loop:



; ======== CHECKING KEYBOARD ========

handle_keyboard:
    mov ah, 0x01            ; Check if a key has been pressed
    int 0x16
    jz .no_move               ; Jump if no key is in the keyboard BULLETS_BUFFER
    xor ax,ax            ; Get the key press
    int 0x16
    .test_up:
    cmp ah, 0x48    ; Up
    jne  .test_down
    ; left?
    sub word [PLAYER_POS], 320*4
    .test_down:
    cmp ah, 0x50    ; Down
    jne .redraw
    add word [PLAYER_POS], 320*4
    
    .redraw:
    sub word [ENEMIES], 8
    jmp redraw_screen
    .no_move:



; ======== DELAY CYCLE ========

delay_timer:
    mov ax, [TIMER]
    inc ax
    .wait:
        cmp [TIMER], ax
        jl .wait

jmp game_loop


; ======== END GAME LOOP ========

draw_sprite:
    mov di, [SPRITE_POS]              ; Store in DI for ES:DI addressing
    mov cx, SPRITE_SIZE               ; Number of rows (each byte is a row in this example)
    mov byte [PIXEL_MASK], 0x80 ; 8 positions
   
    .draw_row:
        push cx                 ; Save CX (rows left)
        mov si, bx
        mov cx, SPRITE_SIZE              ; rows
        xor ah, ah               ; Clear AH to use it for bit testing
        .read_pixel:
            lodsb                   ; Load byte into AL and increment SI
            and al, [PIXEL_MASK]      ; Test the leftmost bit
            cmp al, [PIXEL_MASK]
            jnz .next_pixel          ; If the bit is 0, skip drawing
        .draw_pixel:
            xor ax,ax
            mov byte al, [SPRITE_COLOR]
            mov ah, al
            mov word [es:di], ax         ; Write back to video memory
        .next_pixel:
            inc di                  ; Move to next pixel in the row
            inc di
            loop .read_pixel        ; Repeat for each bit in the byte
        shr byte [PIXEL_MASK], 1 ; Shift left to test the next bit
        add di, 320 - 16         ; Move DI to the start of the next line (assuming screen width is 320 pixels)
        dec word [SPRITE_COLOR]
        pop cx                  ; Restore CX (rows left)
        loop .draw_row          ; Process next row
    mov byte [PIXEL_MASK], 0x80 ; 8 positions
    ret

sprite_test:
db 10111101b
db 01111110b
db 00101100b
db 00011000b

; ======== BOOTSECTOR  ========

times 507 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X'            ; P1X signature 4b
dw 0xAA55