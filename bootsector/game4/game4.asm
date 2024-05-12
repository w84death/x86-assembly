; GAME4 - EMOJI8086
; Description: A basic template for an Assembly program using NASM
; Author: [Your Name]
; Date: [Date]
[bits 16]
[org 0x7c00]
[cpu 8086]

section .data
    MLT dw -320,-319,1,321,320,319,-1,-321  ; Movement Lookup Table

    sprites:
    ; fly
    db 01100000b
    db 10010110b
    db 01001001b
    db 00110010b
    db 01011100b
    db 01111101b
    db 00011110b
 

section .text
 
mov ax, 0x0004      ; set video mode 320x200x4 CGA
int 0x10            ; BIOS video service interrupt

mov ax, 0xB800      ; CGA video memory segment for graphics
mov es, ax          ; set ES to point to the video segment

xor di, di           ; set DI to point to the first byte of video memory
mov cx, 32000     ; calculate the total number of pixels on the screen
mov al, 0x22        ; set the color attribute to pink (0x22)
mov ah, al          ; duplicate the color attribute in AH
rep stosw           ; store the color attribute in video memory


    mov si, sprites     ; Set SI to point to the sprite data
    mov di, 320*100+100 ; Set DI to the position where the sprite will be drawn
    mov bl, 0x11        ; Set BL to the color attribute for the sprite
    call draw_sprite    ; Call the draw_sprite subroutine

    jmp $               ; Infinite loop


draw_sprite:
    MOV DX, 7    ; Number of lines in the sprite
    .draw_row:
        PUSH DX             ; Save DX
        MOV AL, [SI]        ; Get sprite row data
        MOV AH, 0           ; Clear AH
        MOV CX, 8           ; 8 bits per row

    .draw_pixel:
        SHL AL, 1           ; Shift left to get the next bit into carry flag
        JNC .skip_pixel     ; If carry flag is 0, skip setting the pixel
        MOV [ES:DI], BL     ; Set the pixel

    .skip_pixel:
        INC DI              ; Move to the next pixel position horizontally
        LOOP .draw_pixel    ; Repeat for all 8 pixels in the row

        POP DX              ; Restore DX
        INC SI
        ADD DI, 320         ; Move to the next line in the video buffer
        SUB DI, 8           ; Adjust DI back to the start of the line
        DEC DX              ; Decrement row count
        JNZ .draw_row       ; If there are more rows, draw the next one
    ret


; ======== BOOTSECTOR  ========
times 507 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X'            ; P1X signature 4b
dw 0xAA55
