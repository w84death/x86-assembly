; VGA FRAMEWORK
; Description: 
;   This is a simple VGA framework for DOS written in x86 assembly language.
;   The game uses VGA 320x200x256 colors mode, doublebuffering.
;   Minimum CPU is Intel 386.
;
; Author: Krzysztof Krystian Jankowski
; Date: 2024-06/16
; License: MIT

bits 16                                     ; 16-bit mode          
org 0x7c00                                  ; Boot sector origin
cpu 386                                     ; Minimum CPU is Intel 386

; =========================================== MEMORY ===========================

VGA_MEMORY_ADR equ 0xA000                   ; VGA memory address
DBUFFER_MEMORY_ADR equ 0x9000               ; Doublebuffer memory address
SCREEN_BUFFER_SIZE equ 0xFA00               ; Size of the VGA buffer size
TIMER equ 0x046C                            ; BIOS timer

BASE_MEM equ 0x7e00                         ; Base memory address
PLAYER_POS equ BASE_MEM+0x00                ; Ship position,2 bytes
PLAYER_DIR equ BASE_MEM+0x02                ; Ship direction,1 byte

; =========================================== MAGIC NUMBERS ====================

SCREEN_WIDTH equ 320                        ; VGA 13h Resolution:
SCREEN_HEIGHT equ 200                       ; 320x200 pixels
SCREEN_CENTER equ SCREEN_WIDTH*SCREEN_HEIGHT/2+SCREEN_WIDTH/2 ; Center

SPRITE_SIZE equ 8                           ; 8 pixels per sprite line
SPRITE_LINES equ 8                          ; 8 lines per sprite  

COLOR_BACKGROUND equ 0x999b                 ; Color for background

; =========================================== BOOTSTRAP ========================

_start:
    xor ax,ax                               ; Clear AX
    mov ds,ax                               ; Set DS to 0
    mov ax,0x13                             ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt  
    
    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop es                                  ; as target

; =========================================== GAME LOOP ========================

restart_game:
        
; =========================================== REAL-TIME GAME LOOP ==============

game_loop:

; =========================================== DRAW BACKGROUND ==================

draw_bg:
    mov ax,COLOR_BACKGROUND                 ; Set background color (2 bytes)
    mov cx,SCREEN_BUFFER_SIZE               ; Set buffer size to fullscreen
    rep stosw                               ; Fill the buffer with color
    
    
; =========================================== KEYBOARD INPUT ===================


; =========================================== VGA BLIT =========================

call vga_blit                               ; Update screen

; =========================================== DELAY CYCLE ======================

delay_timer:
    mov ax,[TIMER]                          ; Get current timer value
    inc ax                                  ; Increment it by 1 cycle (42ms)
    .wait:
        cmp [TIMER],ax                      ; Compare with the current timer
        jl .wait                            ; Loop until equal

; =========================================== END OF GAME LOOP =================

jmp game_loop                               ; Repeat the game loop



; =========================================== PROCEDURES ======================



; =========================================== VGA BLIT PROCEDURE ===============

vga_blit:
    push es
    push ds

    push VGA_MEMORY_ADR                     ; Set VGA memory
    pop es                                  ; as target
    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop ds                                  ; as source
    mov cx,0x7D00                           ; Half of 320x200 pixels
    xor si,si                               ; Clear SI
    xor di,di                               ; Clear DI
    rep movsw                               ; Push words (2x pixels)

    pop ds
    pop es
    ret

; =========================================== DRAWING SPRITE PROCEDURE =========

draw_sprite:
    pusha
    mov dx,SPRITE_LINES                     ; Number of lines in the sprite
    .draw_row: 
        mov al,[si]                         ; Get sprite row data
        mov cx,SPRITE_SIZE                  ; 8 bits per row
        .draw_pixel:
            shl al,1                        ; Shift left to get the pixel out
            jnc .skip_pixel                 ; If carry flag is 0,skip
            mov [es:di],bl                  ; Carry flag is 1,set the pixel
        .skip_pixel:
            inc di                          ; Move to the next pixel position
            loop .draw_pixel                ; Repeat for all 8 pixels in the row
        inc si
    add di,320-SPRITE_SIZE                  ; Move to the next line
    dec dx                                  ; Decrement row count
    jnz .draw_row                           ; Draw the next row
    popa
    ret

; =========================================== DATA =============================

MLT dw -322,-318,318,322                    ; Movement Lookup Table 
                                            ; 0 - up/left
                                            ; 1 - up/right
                                            ; 2 - down/left
                                            ; 3 - down/right      
; p1x_sprite:
db 0x00,0xD5,0x75,0xD2,0x95,0x95,0x95,0x00  ; P1X 8 bytes


; =========================================== BOOT SECTOR ======================

times 507 - ($ - $$) db 0                   ; Pad remaining bytes
p1x db 'P1X'                                ; P1X signature 4b
dw 0xAA55                                   ; Boot signature