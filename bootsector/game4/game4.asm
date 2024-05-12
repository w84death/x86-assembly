[org 0x7c00]
cpu 8086
use16

mov ax, 0x0004      ; set video mode 320x200x4 CGA
int 0x10            ; BIOS video service interrupt

mov ax, 0xB800      ; CGA video memory segment for graphics
mov es, ax          ; set ES to point to the video segment

xor di, di           ; set DI to point to the first byte of video memory
mov cx, 32000     ; calculate the total number of pixels on the screen
mov al, 0x22        ; set the color attribute to pink (0x22)
mov ah, al          ; duplicate the color attribute in AH
rep stosw           ; store the color attribute in video memory


times 510-($-$$) db 0
dw 0xaa55
