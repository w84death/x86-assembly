; GAME4 - SPACE SHIP GAME
; Description: A simple space ship game
; Author: [Your Name]
; Date: [Date]
bits 16                                     ; 16-bit mode          
org 0x7c00                                  ; Boot sector origin
cpu 286                                     ; Minimum CPU is Intel 286

; =========================================== MEMORY ===========================

VGA_MEMORY_ADR equ 0xA000                   ; VGA memory address
DBUFFER_MEMORY_ADR equ 0x1000               ; Doublebuffer memory address
SCREEN_BUFFER_SIZE equ 0xFA00               ; Size of the VGA buffer size
TIMER equ 0x046C                            ; BIOS timer

BASE_MEM equ 0x7e00                         ; Base memory address
LIFE equ BASE_MEM+0x00                      ; Number of lifes, 1 byte
LEVEL equ BASE_MEM+0x01                     ; Current level, 2 bytes
SHIP_POS equ BASE_MEM+0x03                  ; Ship position, 2 bytes

; =========================================== MAGIC NUMBERS ====================

SCREEN_WIDTH equ 320                        ; 320x200 pixels
SCREEN_HEIGHT equ 200
SCREEN_CENTER equ SCREEN_WIDTH*SCREEN_HEIGHT/2+SCREEN_WIDTH/2 ; Center
PLAYER_START_POS equ SCREEN_WIDTH*180+SCREEN_WIDTH/2          ; Player start position

SPRITE_SIZE equ 8                           ; 8 pixels per sprite line
SPRITE_LINES equ 7                          ; 7 lines per sprite  
PALETTE_SIZE equ 0x1E                       ; 30 colors 

; =========================================== BOOTSTRAP ========================

_start:
    xor ax, ax                              ; Clear AX
    mov ds, ax                              ; Set DS to 0
    mov ax, 0x13                            ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt  
    
    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop es                                  ; as target




restart_game:
    mov word [LEVEL], 0x18                  ; Starting level
    mov byte [LIFE], 0x03                   ; Starting lifes
    mov word [SHIP_POS], PLAYER_START_POS   ; Starting ship position

; =========================================== MAIN GAME LOOP ===================

game_loop:


; =========================================== DRAW BACKGROUND ==================

draw_bg:
    mov ax, 0x1010                          ; Set color 0x10
    mov dx, 12                              ; We have 8 bars
    .draw_bars:
        mov cx, 320*200/64                  ; One bar of 320x200
        rep stosw                           ; Write to the doublebuffer
        inc ax                              ; Increment color index for next bar
        xchg al, ah                         ; Swap colors 
        dec dx                              ; Decrement bar counter
        jnz .draw_bars                      ; Repeat for all bars


    mov cx, 320*200/3                       ; Half of the screen    
    rep stosw                               ; Write to the doublebuffer

; =========================================== DRAW SPRITE ======================

draw_ship:
    mov bx, 0x1E                            ; Set color 0x1E
    mov si, sprites                         ; Set sprite data
    mov di, [SHIP_POS]                      ; Set sprite position
    call draw_sprite                        ; Draw the sprite

; =========================================== KEYBOARD INPUT ===================

handle_keyboard:
    in al, 60h                              ; Read keyboard
    
    cmp al, 0x39                            ; Check if Spacebar is pressed
    jne .no_spacebar

    .no_spacebar:
    cmp al, 0x4B                            ; Left
    jne .no_left
        dec word [SHIP_POS]                 ; Move left
    .no_left:
    cmp al, 0x4D                            ; Right
    jne .no_right
        inc word [SHIP_POS]                 ; Move right
    .no_right:

; =========================================== VGA BLIT =========================

vga_blit:
    push es
    push ds

    push VGA_MEMORY_ADR                     ; Set VGA memory
    pop es                                  ; as target
    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop ds                                  ; as source
    mov cx, 0x7D00                          ; Half of 320x200 pixels
    xor si, si                              ; Clear SI
    xor di, di                              ; Clear DI
    rep movsw                               ; Push words (2x pixels)

    pop ds
    pop es

; =========================================== DELAY CYCLE ======================

; delay_timer:
;     mov ax, [TIMER]                         ; Get current timer value
;     inc ax                                  ; Increment it by 1 cycle (42ms)
;     .wait:
;         cmp [TIMER], ax                     ; Compare with the current timer
;         jl .wait                            ; Loop until equal

wait_for_vsync:
    mov dx, 0x03DA                              ; VGA status register
    in al, dx                                   ; Read from VGA status register
    test al, 0x08                               ; Check vertical retrace bit
    jnz wait_for_vsync

; =========================================== END OF GAME LOOP =================

jmp game_loop                               ; Repeat the game loop

; =========================================== DRAWING SPRITE PROCEDURE =========

draw_rect:
    xor ax, ax
    xor dx, dx
    mov byte al, [si+3]
    mov byte dl, [si+2]
    mov di, [si]
    .draw_line: 
        mov cx, [si+1]
        rep stosb
        add di, 320
        sub di, cx
        dec dl
        jnz .draw_line
    ret

; =========================================== DATA =============================


rects:
    dw 320*10
    db 100
    db 70
    db 5


MLT dw -320,-319,1,321,320,319,-1,-321      ; Movement Lookup Table
sprites:
db 00011000b
db 00100100b
db 01011010b
db 01111110b
db 01111110b
db 11111111b
db 11011011b
db 10100101b
; ======== BOOTSECTOR  ========
times 507 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X'            ; P1X signature 4b
dw 0xAA55
