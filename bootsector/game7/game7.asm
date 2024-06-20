org 0x7c00
use16

VGA_MEMORY_ADR equ 0xA000                   ; VGA memory address
DBUFFER_MEMORY_ADR equ 0x8000               ; Doublebuffer memory address
SCREEN_BUFFER_SIZE equ 0xFa00               ; Size of the VGA buffer size
TIMER equ 0x046C                            ; BIOS timer
SPRITE_WIDTH equ 0x08
SPRITE_LINES equ 0x08
STATE_ADR equ 0xfe00
STATE_ON equ 0x01
STATE_OVER equ 0x02
STATE_NEWALIEN equ 0x03
; game variables 01-0f
HEALTH_ADR equ 0x7e01                       ; 1 byte
WEAPON_SHOOT_ADR equ 0x7e02                 ; 1 byte
HITS_ADR equ 0x7e03
WEAPON_AIM_ADR equ 0x7e05
; aliens
ALIENS_ADR equ 0x7e10


start:
    mov ax,0x13                             ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt

    push DBUFFER_MEMORY_ADR                 ; Set doublebuffer memory
    pop es                                  ; as target

    mov ax, 7
    mov cx,0 ; min pos
    mov dx,320 ; max pos
    int 33h

    mov byte [STATE_ADR],STATE_ON
    mov byte [HEALTH_ADR],0x04
    mov word [HITS_ADR],0x00


create_aliens:
    mov si, ALIENS_ADR
    mov word [si], 320*20+160
    mov word [si+2],0x0000
    mov word [si+4], 0xffff

; main loop
game_loop:
    mov ax,0x1112
    mov cx,SCREEN_BUFFER_SIZE               ; Set buffer size to fullscreen
    rep stosw                               ; Fill the buffer with color


mouse_handler:
    mov ax, 0x0003
    int 0x33
    cmp byte [WEAPON_SHOOT_ADR], 0x0
    jnz .done
        mov byte [WEAPON_SHOOT_ADR],al
    .done:
    mov word [WEAPON_AIM_ADR], cx
    mov word [WEAPON_AIM_ADR+2], dx
    mov bx, 320
    mov ax, dx
    mul bx
    add ax, cx
    mov di, ax
    mov ax, 0x0f
    stosb


; get aliens

cmp byte [STATE_ADR], STATE_ON
jne skip_aliens_loop

  mov si, ALIENS_ADR
  ;xor bx,bx
aliens_loop:

  rdtsc
  add ax, si
  xor ax, 0x1337
  and ax, 0x0f ; MLT size
  mov di, ax
  shl di, 1
  mov ax, [MLT+di]
  add ax, [MLT+di]
  mov di,[si]
  add di, ax
  jnz .ok1
  inc di
  .ok1:
  add ax, 320*40
  cmp di, 320*160
  jb .ok2
  and di, 320*160
  .ok2:
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
      mov byte [STATE_ADR], STATE_OVER
      .game_on:
      .hit:
      push si
      mov bx, 0x04
      mov si, HitSpr
      call draw_sprite
      call vga_blit
      pop si
      rdtsc
      and ax, 320*160
      add ax, 320*20
      mov [si-2], ax
      mov word [si], 0x0000
  .continue:
  mov byte [si], bl
  shr bl, 4
  add bl,0x10   ; grays 10-1f

; draw sprite
  push si
  mov si, UfoSpr
  call draw_sprite
  pop si

; move to next slot

  inc si
  inc si

  mov ax,[si]
  cmp ax,0xffff
  jnz aliens_loop

skip_aliens_loop:


add_alien:
    mov byte al, [STATE_ADR]
    cmp al, STATE_NEWALIEN
    jne .skip
        mov byte [STATE_ADR], STATE_ON

        rdtsc
        and ax, 320*160
        add ax, 320*20
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
    mov di, 320*4+4
    .l:
    mov bx, 0x28
    call draw_sprite
    add di, 0x8
    loop .l
    .skip:

draw_hits_counter:
    mov word cx, [HITS_ADR]
    cmp cx,0x0
    jz .skip
    mov si, OneMoreSpr
    mov di, 320*4+4+56
    .l:
    mov bx, 0x0f
    call draw_sprite
    add di, 0x3
    loop .l
    .skip:

    call vga_blit

; =========================================== DELAY CYCLE ======================

delay_timer:
    mov ax,[TIMER]                          ; Get current timer value
    inc ax                                  ; Increment it by 1 cycle (42ms)
    .wait:
        cmp [TIMER],ax                      ; Compare with the current timer
        jl .wait                            ; Loop until equal


    jmp game_loop

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
    add di,320-SPRITE_WIDTH                 ; Move to the next line
    dec dx                                  ; Decrement row count
    jnz .draw_row                           ; Draw the next row
    popa
    ret


; Data segment

MLT dw -322,-318,318,322,-1,1,-1,1,-1,-1,1,1,-1,-1,1,1      
                                            ; Movement Lookup Table

UfoSpr:
db 10111101b
db 01011010b
db 11100111b
db 10011001b
db 11111111b
db 00111100b
db 01011010b
db 11100111b
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
db 00111100b
db 01100110b
db 01000010b
db 01100110b
db 01111110b
db 00111100b
db 01000010b
db 00111100b
OneMoreSpr:
db 00000100b
db 00001000b
db 00010000b
db 00010000b
db 00100000b
db 00100000b
db 01000000b
db 10000000b

; =========================================== BOOT SECTOR ======================

times 507 - ($ - $$) db 0                   ; Pad remaining bytes
p1x db 'P1X'                                ; P1X signature 4b
dw 0xAA55                                   ; Boot signature
