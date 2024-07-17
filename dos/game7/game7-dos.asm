org 0x100
use16

VGA_MEMORY_ADR equ 0xA000                   ; VGA memory address
DBUFFER_MEMORY_ADR equ 0x8000               ; Doublebuffer memory address

SPRITE_WIDTH equ 0x08
SPRITE_LINES equ 0x08

STATE_ADR equ 0xfe00
STATE_ON equ 0x01
STATE_OVER equ 0x02
STATE_NEWALIEN equ 0x03
; game variables 01-0f
HEALTH_ADR equ 0x7e01                       ; 1 byte
HITS_ADR equ 0x7e02                         ; 2
WEAPON_AIM_ADR equ 0x7e04                   ; 4
; aliens
ALIENS_ADR equ 0x7e10


start:
    mov ax,0x13                             ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt

    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop es                                  ; as target


    mov ax, 7
    mov cx, 1
    mov dx,319
    int 33h

    ; hide cursor
    mov ax, 2    ; Function 2 - Hide mouse cursor
    int 33h      ; Call mouse interrupt

restart_game:
    mov byte [STATE_ADR],STATE_ON
    mov byte [HEALTH_ADR],0x0a
    mov word [HITS_ADR],0x00


create_aliens:
    mov si, ALIENS_ADR
    mov word [si], 320*100+160
    ;mov word [si+2], 0x0000
    mov word [si+4], 0xffff

; main loop
game_loop:

    draw_bg:
    xor di,di
    mov cx, 200
    .l:
       push cx
       xchg ax, cx
       add ax, bp
       shr ax, 2
       and al,0x05
       add al, 0x12
       mov cx, 320
       rep stosb
       pop cx
    loop .l

    inc bp
    inc bp

mouse_handler:
    mov ax, 0x0003
    int 0x33
    mov word [WEAPON_AIM_ADR], cx
    mov word [WEAPON_AIM_ADR+2], dx
    ; draw crosshair dot
    imul dx, 320
    add dx, cx
    mov di,dx
    mov al,0x0f
    stosb


mov si, ALIENS_ADR
aliens_loop:

  rdtsc
  and ax, 0x07 ; MLT size
  mov di, ax
  shl di, 1
  mov ax, [MLT+di]
  add ax, [MLT+di]
  mov di,[si]
  add di, ax
  mov [si],di

  inc si
  inc si

  ; check collisions
  mov ax,di    ; linear pos
  mov bx,320
  xor dx,dx
  div bx       ; ax=y, dx=x
  mov word cx, [WEAPON_AIM_ADR]
  cmp cx,dx    ; aim on the right?
  jl .no_hit
  add dx,SPRITE_WIDTH ; move by sprite size
  cmp cx,dx   ; aim on the right?
  jg .no_hit

  mov word cx,[WEAPON_AIM_ADR+2]
  cmp cx,ax     ; aim below?
  jl .no_hit
  add ax,SPRITE_LINES ; move by sprite size
  cmp cx, ax          ; aim below?
  jg .no_hit

  inc word [HITS_ADR]
  mov word ax, [HITS_ADR]
  ; check for win
  and al, 0x05
  jnz .hit
  mov byte [STATE_ADR],STATE_NEWALIEN
  jmp .hit

  .no_hit:

  mov bl,[si]
  inc bl
  cmp bl, 0xff ; alien hits player
  jb .continue
      dec byte [HEALTH_ADR]
      cmp byte [HEALTH_ADR], 0x0
      ja .game_on
        .wait_for_esc:
        in ax, 0x60
        dec al
        jnz .wait_for_esc
        out 60h,al
        jmp restart_game
      .game_on:
      .hit:
      push si
      mov bx, 0x28
      mov si, HitSpr
      call draw_sprite
      call vga_blit
      pop si
      rdtsc
      and ax, 320*32
      mov [si-2], ax
      mov word [si], 0x0000
  .continue:
  mov byte [si], bl
  shr bl, 4
  add bl,0x10   ; grays 10-1f

; draw sprite
  push si
  mov si, EnemySpr
  mov ax, bx
  shr ax,1
  jnc .ok
  add si, 8
  .ok:
  call draw_sprite
  pop si

  inc si
  inc si
  mov ax,[si]
  cmp ax,0xffff
  jnz aliens_loop

add_alien:
    mov byte al, [STATE_ADR]
    cmp al, STATE_NEWALIEN
    jne .skip
        mov byte [STATE_ADR], STATE_ON
        rdtsc
        and ax, 320*32
        mov [si], ax
        mov word [si+2], 0x0000
        mov word [si+4], 0xffff
   .skip:

draw_health_bar:
    xor cx,cx
    mov byte cl, [HEALTH_ADR]
    cmp cx,0x0
    jz .skip
    mov si, HealthSpr
    mov di, 320*4+80
    mov bx, 0x28
    .l:
        call draw_sprite
        add di, 0x10
    loop .l
    .skip:

draw_hits_counter:
    mov word cx, [HITS_ADR]
    cmp cx,0x0
    jz .skip
    mov si, OneMoreSpr
    mov di, 320*190+4
    .l:
    mov bx, 0x1e
    call draw_sprite
    add di, 0x3
    loop .l
    .skip:

    call vga_blit

; =========================================== DELAY CYCLE ======================

delay:
    push es
    push 0x0040
    pop es
    mov bx, [es:0x006C]  ; Load the current tick count into BX
wait_for_tick:
    mov ax, [es:0x006C]  ; Load the current tick count
    sub ax, bx           ; Calculate elapsed ticks
    jz wait_for_tick     ; If not enough time has passed, keep waiting
    pop es


; =========================================== ESC OR LOOP =====================

    in al,0x60                           ; Read keyboard
    dec al
    jnz game_loop

; =========================================== TERMINATE PROGRAM ================

    mov ax, 0x0003
    int 0x10

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
        mov cx,SPRITE_WIDTH                 ; 8 bits per row
        .draw_pixel:
            shl al,1                        ; Shift left to get the pixel out
            jnc .skip_pixel                 ; If carry flag is 0,skip
            mov [es:di],bl                  ; Carry flag is 1,set the pixel
        .skip_pixel:
            inc di                          ; Move to the next pixel position
            loop .draw_pixel                ; Repeat for all 8 pixels in the row
        inc si
    add di,320-SPRITE_WIDTH                              ; Move to the next line
    dec dx                                  ; Decrement row count
    jnz .draw_row                           ; Draw the next row
    popa
    ret


; Data segment

MLT dw 1,-1,318,322,-1,1,-2,2      ; Movement Lookup Table

EnemySpr:
; Frame 1
db 11000011b
db 01011010b
db 00111100b
db 01011010b
db 11111111b
db 10100101b
db 10011001b
db 01000010b
; Frame 2
db 00000000b
db 01011010b
db 11111111b
db 01011010b
db 11111111b
db 10100101b
db 10011001b
db 01000010b
HitSpr:
db 10010001b
db 01000010b
db 00011000b
db 10101100b
db 00111101b
db 00011000b
db 01000010b
db 10010001b
HealthSpr:
db 01111110b
db 11000011b
db 10011001b
db 10111101b
db 10111101b
db 10011001b
db 11000011b
db 01111110b
OneMoreSpr:
db 00000100b
db 00001000b
db 00010000b
db 00010000b
db 00100000b
db 00100000b
db 01000000b
db 10000000b



;times 510-($-$$) db 0
db "P1X"
;dw 0xAA55
