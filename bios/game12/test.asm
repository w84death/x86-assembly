org 100h          ; Assemble as a .COM program

;------------------------------------------------------------------------------
; Set CGA mode 320x200, 4 colors (Mode 4).
;------------------------------------------------------------------------------
start:
    mov ax, 0004h  ; AH=0 (Set Video Mode), AL=4 (320×200, 4-color CGA)
    int 10h

;------------------------------------------------------------------------------
; Setup segment for CGA graphics memory (B800:0000).
;------------------------------------------------------------------------------
    mov ax, 0B800h
    mov es, ax

;------------------------------------------------------------------------------
; Example: Plot a single pixel at (x=50, y=50) with color=2.
; Color can be 0..3 in 4-color mode (2 bits per pixel).
;------------------------------------------------------------------------------
    mov bx, 50      ; BX = y coordinate
    mov dx, 50      ; DX = x coordinate
    mov al, 2       ; AL = color (lower 2 bits only)
    call plot_pixel

;------------------------------------------------------------------------------
; Wait for a key press before returning to DOS.
;------------------------------------------------------------------------------
    mov ah, 0       ; AH=0: Read keyboard input
    int 16h

    mov ax, 4C00h
    int 21h

;------------------------------------------------------------------------------
; plot_pixel: plots a pixel in 320×200 4-color CGA mode.
; Input:  X in DX, Y in BX, color in AL (0 to 3).
;------------------------------------------------------------------------------
plot_pixel:
    ; 
    ; Each line has 80 bytes (320 pixels / 4 pixels per byte).
    ; Offset = y * 80 + (x / 4)
    ; Within that byte, (x % 4) selects which 2 bits to set.
    ;

    ; Calculate offset in memory: DI = BX*80 + DX/4
    push ax
    push bx
    push dx

    mov ax, bx        ; ax = y
    shl ax, 4         ; ax = y * 16
    add ax, bx        ; ax = y * 17
    shl ax, 2         ; ax = y * 68
    shl dx, 14        ; shift dx right by 2 bits??? That's not correct. Let's do it step by step:

    ; Let's do it more direct to avoid confusion:
    ; offset = y * 80 + (x >> 2)
    ; We'll compute that in AX, then move to DI

    ; We already have y in BX, x in DX
    mov ax, bx        ; ax = y
    imul ax, 80       ; ax = y * 80
    shr dx, 2         ; dx = x >> 2
    add ax, dx        ; ax = y*80 + (x>>2)
    mov di, ax        ; store in DI

    ; Now we handle which 2 bits to modify in that byte
    ; sub-pixel index = x & 3
    ; shift that by 1 => 2 bits per pixel
    mov ax, dx        ; ax = (x>>2) from above
    shl ax, 2         ; multiply by 4 to undo the shift we did earlier, not quite right:
                      ; let's get the real x again. We saved it in push dx above, so let's pop it:

    pop dx            ; restore x
    push dx           ; push it back for stack alignment later

    mov cx, dx        ; cx = x
    and cx, 3         ; cx = x % 4
    shl cx, 1         ; each pixel is 2 bits, so shift by 1

    ; read the current byte at [es:di]
    mov bl, [es:di]   ; bl = current pixel byte

    ; clear the pixel's 2 bits in bl
    ; we need a mask that has 0 in the bits we want to set, and 1 in the others
    ; position is in cx, so build a mask
    ; e.g., if cx=2 => shift 3 (0b11) left by 2 => 0b1100 
    mov ah, 3         ; 0b11
    shl ah, cl        ; shift left by cx
    not ah            ; invert bits => bits for that pixel are now 0

    and bl, ah        ; clear those 2 bits in bl

    ; now place the new pixel color (AL) in the correct position
    ; color is in AL, but let's keep it in DL to avoid overwriting
    pop dx            ; restore original color in AL
    mov dl, al        ; dl = color
    and dl, 3         ; ensure color is 2 bits only

    ; shift dl by cx to place it in the correct location
    shl dl, cl

    ; combine it with bl
    or bl, dl

    ; write back to video memory
    mov [es:di], bl

    pop dx
    pop bx
    pop ax
    ret