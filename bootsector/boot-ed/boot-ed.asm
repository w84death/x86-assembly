[bits 16]
[org 0x7c00]

; ======== TEXT INITIALIZATION ========
[org 0x7c00]  ; Origin, BIOS loads the boot sector here
[bits 16]     ; We are working in 16-bit real mode

start:
    mov ax, 0003h     ; Function 0x00 and video mode 0x03 (80x25 text mode)
    int 10h           ; Call video interrupt

    mov ax, 0xB800    ; Segment address of text mode video memory
    mov es, ax        ; Set ES to point to the video segment
    xor di, di        ; Start at the beginning of video memory
    mov ax, 0320h     ; Attribute byte 07 (white on black), and space character (0x20)
    mov cx, 2000      ; There are 2000 character positions in 80x25 text mode
    rep stosw

    xor ax, ax          ; Clear AX register
    mov ds, ax          ; Set DS to 0
    mov es, ax          ; Set ES to 0

    ; Set up stack
    mov ss, ax
    mov sp, 0x7C00
    cli                 ; Clear interrupts

    ; Read second sector
    mov ah, 0x02        ; AH = 02h -> Read sectors from drive
    mov al, 0x01        ; AL = 1 sector
    mov ch, 0x00        ; CH = Cylinder 0
    mov cl, 0x02        ; CL = Sector 2 (sector number starts from 1)
    mov dh, 0x00        ; DH = Head 0
    mov dl, 0x00        ; DL = Drive 0x80 (first hard disk) 0x00 Floppy
    mov bx, 0x8000      ; ES:BX = Buffer to read to, after the boot sector
    mov es, bx
    mov bx, 0x0000
    int 0x13            ; BIOS disk interrupt
    jc  read_error      ; Jump if error

    ; Display characters until '0x00' found
    xor si,si           ; Clear the source index
display_loop:
    cmp byte [es:si], 0x00 ; Compare byte at ES:SI with 0
    je  done            ; If zero-byte, end
    mov ah, 0x0E        ; AH = 0Eh -> Teletype output
    mov al, [es:si]     ; AL = character to write
    int 0x10            ; BIOS video interrupt
    inc si              ; Move to next character
    jmp display_loop    ; Repeat

done:
; Initialize video segment
    mov ax, 0xB800
    mov es, ax
    xor di, di          ; Start writing at the top-left corner of the screen
    
    keyboard_loop:
    xor ax, ax          ; AH = 0, AL = 0
    int 0x16            ; BIOS keyboard interrupt
    mov ah, 0x0E        ; Attribute byte for the character (e.g., 0x0E = yellow on black)
    stosw               ; Write AX to video memory at ES:DI and increment DI by 2 

    jmp keyboard_loop   ; Repeat indefinitely

read_error:
    jmp $


; ======== BOOTSECTOR  ========

times 506 - ($ - $$) db 0  ; Pad remaining bytes
p1x db 'P1X', 0            ; P1X signature 4b
dw 0xAA55                  ; Boot signature at the end of 512 bytes