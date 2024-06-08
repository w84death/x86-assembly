BITS 16                  ; 16-bit code
org 0x7E00               ; This code will be loaded at address 0x7E00


BASE_MEM equ 0x7e00                         ; Base memory address
LIFE equ BASE_MEM+0x00                      ; Number of lifes, 1 byte
LEVEL equ BASE_MEM+0x01                     ; Current level, 2 bytes

SPRITE_SIZE equ 8                           ; 8 pixels per sprite line
SPRITE_LINES equ 7                          ; 7 lines per sprite  
PALETTE_SIZE equ 0x1E                       ; 30 colors 


; =========================================== SET PALETTE ======================

; Anapurna by Dee
palette:
    SALC
    MOV DX,3C8H
    OUT DX,AL
    INC DX
    .1:
    PUSH AX
    OUT DX,AL
    SHR AX,1
    OUT DX,AL
    SHR AX,1
    OUT DX,AL
    POP AX
    INC AX
    JNZ .1
    retf

; =========================================== DRAW BACKGROUND ==================

draw_bg:
    xor di,di                               ; Clear DI                     
    xor bx,bx                               ; Clear BX
    mov ax, 0x0808                          ; Multiply level by 0x0404
    mov dx, 16                              ; We have 8 bars
    .draw_bars:
        mov cx, 320*200/32                  ; One bar of 320x200
        rep stosw                           ; Write to the doublebuffer
        inc ax                              ; Increment color index for next bar
        xchg al, ah                         ; Swap colors 
        dec dx                              ; Decrement bar counter
        jnz .draw_bars                      ; Repeat for all bars
    retf

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
    retf


; =========================================== BOOTSECTOR =======================

times 507 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X'            ; P1X signature 4b
dw 0xAA55