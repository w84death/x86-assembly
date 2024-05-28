; GAME4 - EMOJI8086
; Description: A basic template for an Assembly program using NASM
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

; =========================================== MAGIC NUMBERS ====================

SCREEN_WIDTH equ 320                        ; 320x200 pixels
SCREEN_HEIGHT equ 200
SCREEN_CENTER equ SCREEN_WIDTH*SCREEN_HEIGHT/2+SCREEN_WIDTH/2 ; Center

SPRITE_SIZE equ 8                           ; 8 pixels per sprite line
SPRITE_LINES equ 7                          ; 7 lines per sprite  
PALETTE_SIZE equ 0x1E                       ; 30 colors 

; =========================================== BOOTSTRAP ========================

_start:
    xor ax, ax                              ; Clear AX
    mov ds, ax                              ; Set DS to 0
    mov ax, 0x13                          ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt  
    
    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop es                                  ; as target



restart_game:
    mov word [LEVEL], PALETTE_SIZE          ; Starting level

; =========================================== MAIN GAME LOOP ===================

game_loop:


; =========================================== DRAW BACKGROUND ==================

draw_bg:
    xor di,di                               ; Clear DI                     
    xor bx,bx                               ; Clear BX
    mov bx, [LEVEL]                         ; Get current level number
    imul ax, bx, 0x0808                     ; Multiply level by 0x0404
    mov dx, 16                              ; We have 8 bars
    .draw_bars:
        mov cx, 320*200/32                  ; One bar of 320x200
        rep stosw                           ; Write to the doublebuffer
        inc ax                              ; Increment color index for next bar
        xchg al, ah                         ; Swap colors 
        dec dx                              ; Decrement bar counter
        jnz .draw_bars                      ; Repeat for all bars


; =========================================== DRAW SPRITE ======================

draw_fly:
    mov bl, 0x0F                            ; Set color to white
    mov si, sprites                         ; Set sprite data
    mov di, SCREEN_CENTER                   ; Set sprite position
    call draw_sprite                        ; Draw the sprite  


; =========================================== KEYBOARD INPUT ===================

handle_keyboard:
    in al, 60h                              ; Read keyboard
    cmp al, 0x39                            ; Check if Spacebar is pressed
    jne .no_spacebar
        dec word [LEVEL]                    ; Move rotation clockvise
        jnz .no_spacebar
            mov word [LEVEL], PALETTE_SIZE  ; Reset level to 0
    .no_spacebar:

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

%ifdef IS_286
%else
delay_timer:
    mov ax, [TIMER]                         ; Get current timer value
    inc ax                                  ; Increment it by 1 cycle (42ms)
    .wait:
        cmp [TIMER], ax                     ; Compare with the current timer
        jl .wait                            ; Loop until equal

%endif

; =========================================== END OF GAME LOOP =================

jmp game_loop                               ; Repeat the game loop

; =========================================== DRAWING SPRITE PROCEDURE =========


draw_sprite:
    mov dx, SPRITE_LINES                    ; Number of lines in the sprite
    .draw_row: 
        mov al, [si]                        ; Get sprite row data
        mov cx, 8                           ; 8 bits per row
        .draw_pixel:
            shl al, 1                       ; Shift left to get the pixel out
            jnc .skip_pixel                 ; If carry flag is 0, skip
            mov [es:di], bl                 ; Carry flag is 1, set the pixel
        .skip_pixel:
            inc di                          ; Move to the next pixel position
            loop .draw_pixel                ; Repeat for all 8 pixels in the row
        inc si
    add di, 312                             ; Move to the next line
    dec dx                                  ; Decrement row count
    jnz .draw_row                           ; Draw the next row
    ret


; =========================================== DATA =============================

MLT dw -320,-319,1,321,320,319,-1,-321      ; Movement Lookup Table
sprites:
db 0x60, 0x96, 0x49, 0x32, 0x5C, 0x7D, 0x1E ; Fly sprite frame 0

; ======== BOOTSECTOR  ========
times 507 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X'            ; P1X signature 4b
dw 0xAA55
