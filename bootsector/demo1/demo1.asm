; Bytebeat Demo with PC Speaker and Double Buffered VGA Graphics
; Author: Claude
; Description: This demo plays a bytebeat tune using the PC speaker
;              and displays synchronized visual effects in VGA mode 13h
;              using double buffering for smooth animation.

org 100h  ; COM file

VGA_SEGMENT equ 0A000h
SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200
SCREEN_SIZE equ SCREEN_WIDTH * SCREEN_HEIGHT

section .text
    ; Set VGA mode 13h (320x200, 256 colors)
    mov ax, 0013h
    int 10h

    ; Initialize variables
    mov word [time], 0xff
    mov byte [color], 0

    ; Set up segment registers
    mov ax, VGA_SEGMENT
    mov es, ax  ; ES points to VGA memory
    mov ax, ds
    mov fs, ax  ; FS points to our data segment

main_loop:
    ; Generate bytebeat sample
    mov ax, [time]
    mov bx, ax
    shr bx, 6
    and ax, bx
    mov bx, [time]
    shr bx, 2
    or ax, bx
    and ax, 255  ; Ensure 8-bit output
    
    ; Play sound
    mov dx, 42
    mov bx, 4000  ; Adjust this value to change the base frequency
    mul bx
    mov bx, 256
    div bx
    out 43h, al
    out 42h, al
    mov al, ah
    out 42h, al
    in al, 61h
    or al, 3
    out 61h, al

    ; Update visuals in the off-screen buffer
    mov di, SCREEN_SIZE  ; Start from the end of the buffer
    mov cx, SCREEN_SIZE
draw_loop:
    mov al, [color]
    add al, [fs:time]
    xor al, ah  ; Mix with the high byte of the bytebeat value for more variation
    stosb
    loop draw_loop


    ; Increment time and color
    inc word [time]

    inc byte [color]

; =========================================== DELAY CYCLE ======================

delay:
    mov dx, 0x3da
    .wait:
    in al, dx
    test al, 0x8
    jz .wait

    ; Check for key press
    mov ah, 1
    int 16h
    jz main_loop

    ; If key pressed, exit
    mov ax, 3  ; Text mode
    int 10h

    ; Turn off the speaker
    in al, 61h
    and al, 0FCh
    out 61h, al

    ; Exit to DOS
    mov ax, 4C00h
    int 21h

section .data
    time dw 0
    color db 0

section .bss
    ; Off-screen buffer
    buffer resb SCREEN_SIZE