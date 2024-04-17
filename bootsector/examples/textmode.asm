[ORG 0x7C00]  ; Set the origin to where the boot sector will be loaded.

; Clear the screen
mov ah, 0x00   ; Function: Set video mode
mov al, 0x03   ; Mode 03: 80x25 text mode
int 0x10       ; BIOS video interrupt

; Initialize ES register for video segment
mov ax, 0xB800
mov es, ax

; Set page number to zero
mov bh, 0

; Set the character and attribute for filling
mov al, ' '         ; Character to fill the screen with (space)
mov bl, 1Eh         ; Attribute (blue background, yellow foreground)

mov dh, 0           ; Initial row
mov dl, 0           ; Initial column

fill_screen:
    ; Set cursor position for each new line
    mov ah, 02h     ; Function to set cursor position
    int 10h         ; BIOS video interrupt

    ; Write characters across the line
    mov ah, 09h     ; Function to write character and attribute
    mov cx, 80      ; Number of characters to write (full row)
    int 10h         ; BIOS video interrupt

    ; Move to the next line
    inc dh          ; Increment row number
    cmp dh, 25      ; Compare with total rows (standard text mode)
    jl fill_screen  ; Loop back if less than 25

; Define the string and its end label for looping
mov si, welcome_msg  ; Point SI to the start of the string
mov ah, 02h
mov dh, 12           ; Initial row
mov dl, 20           ; Initial column
int 10h

print_string:
    lodsb            ; Load the next byte from DS:SI into AL, SI++
    or al, al        ; Check if the character is zero (end of string)
    jz done          ; If zero, we're done
    mov ah, 0x09     ; Function 09h - Write Character and Attribute
    mov bh, 0x00     ; Page number
    mov bl, 0x1E     ; Attribute (blue background, yellow foreground)
    mov cx, 0x01     ; Write each character once
    int 0x10         ; Call BIOS video interrupt
    
    ; Move the cursor right
    mov ah, 0x03     ; Read current cursor position
    int 0x10         ; BX = page, DX = cursor position (DH = row, DL = column)
    inc dl           ; Increment column
    cmp dl, 80       ; Check if we reached the end of the row
    jne update_cursor
    xor dl, dl       ; Reset column to 0 for new line
    inc dh           ; Move to the next row

update_cursor:
    mov ah, 0x02     ; Function to set cursor position
    int 0x10         ; Update cursor position with new values in DH (row) and DL (column)

    jmp print_string ; Loop back to print the next character


done:

; Infinite loop to halt the CPU after printing
jmp $

.data:
welcome_msg db 'Welcome to the P1X boot sector game', 0

times 510 - ($ - $$) db 0  ; Pad remaining bytes to make 510 bytes
dw 0xAA55                  ; Boot signature at the end of 512 bytes
