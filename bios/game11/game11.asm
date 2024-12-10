; GAME10 - Mysteries of the Forgotten Isles
; game10.asm
;
; Description:
; Logic 2D game in VGA graphics, w PC Speaker sound.
;
; Size category: 4096 bytes / 4KB
; Bootloader: 512 bytes
; Author: Krzysztof Krystian Jankowski
; Web: smol.p1x.in/assembly/forgotten-isles/
; License: MIT

org 0x100
use16

jmp start

include 'vectors.asm'

_BG_BUFFER_MEMORY_ equ 0x8000   ; 64k bytes
_DBUFFER_MEMORY_ equ 0x9000   ; 64k bytes
_VGA_MEMORY_ equ 0xA000       ; 64k bytes
_TICK_ equ 1Ah                ; BIOS tick

_GAME_TICK_ equ 0x1007        ; 2 bytes
_GAME_STATE_ equ 0x1009       ; 1 byte


start:
    mov ax,0x13                             ; Init VGA 320x200x256
    int 0x10                                ; Video BIOS interrupt

  set_keyboard_rate:
    xor ax, ax
    xor bx, bx
    mov ah, 03h         ; BIOS function to set typematic rate and delay
    mov bl, 1Fh         ; BL = 31 (0x1F) for maximum repeat rate (30 Hz) and 0 delay
    int 16h             ; Call BIOS


bg:

push _BG_BUFFER_MEMORY_
pop es                                  ; as target
xor di,di
xor si,si

; draw bg
 mov ax, 0x5c5c               ; Set starting sky color
  mov dl, 0x0b                  ; 10 bars to draw
  .draw_sky:
    mov cx, 320*9           ; 3 pixels high
    rep stosw               ; Write to the doublebuffer
    inc ax                  ; Increment color index for next bar
    xchg al, ah             ; Swap colors
    dec dl
    jnz .draw_sky

game_loop:
  push ds

  push _BG_BUFFER_MEMORY_
  pop ds
  xor si, si

  push _DBUFFER_MEMORY_
  pop es               
  xor di, di

  mov cx, 0x7D00
  rep movsw

  pop ds

game:

; draw game

  mov si, LogoVector
  mov bp, 48
  call draw_vector


check_keyboard:
  mov ah, 01h         ; BIOS keyboard status function
  int 16h             ; Call BIOS interrupt
  jz .no_key_press           ; Jump if Zero Flag is set (no key pressed)

  mov ah, 00h         ; BIOS keyboard read function
  int 16h             ; Call BIOS interrupt

    .no_key_press:


vga_blit:
    push es
    push ds

    push _VGA_MEMORY_                     ; Set VGA memory
    pop es                                  ; as target
    push _DBUFFER_MEMORY_                 ; Set doublebuffer memory
    pop ds                                  ; as source
    xor si,si                               ; Clear SI
    xor di,di                               ; Clear DI
    
    mov cx,0x7D00                           ; Half of 320x200 pixels
    rep movsw                               ; Push words (2x pixels)

    pop ds
    pop es


; =========================================== GAME TICK ========================

wait_for_tick:
    xor ax, ax          ; Function 00h: Read system timer counter
    int _TICK_          ; Returns tick count in CX:DX
    mov bx, dx          ; Store the current tick count
.wait_loop:
    int _TICK_          ; Read the tick count again
    cmp dx, bx
    je .wait_loop       ; Loop until the tick count changes

inc word [_GAME_TICK_]  ; Increment game tick

; =========================================== ESC OR LOOP ======================

  in al, 0x60                  ; Read keyboard
  dec al                      ; Decrement AL (esc is 1, after decrement is 0)
  jnz game_loop               ; If not zero, loop again

; =========================================== TERMINATE PROGRAM ================

  exit:

; =========================================== BEEP STOP ========================

  call stop_beep
  mov ax, 0x4c00
  int 0x21
  ret                       ; Return to BIOS/DOS


; =========================================== BEEP PC SPEAKER ==================
; Set the speaker frequency
; Expects: BX - frequency value
; Return: -

beep:
  ;xor bh, bh
  mov al, 0xB6  ; Command to set the speaker frequency
  out 0x43, al   ; Write the command to the PIT chip
  mov ah, bl    ; Frequency value
  out 0x42, al   ; Write the low byte of the frequency value
  mov al, ah
  out 0x42, al   ; Write the high byte of the frequency value
  in al, 0x61    ; Read the PIC chip
  or al, 0x03    ; Set bit 0 to enable the speaker
  out 0x61, al   ; Write the updated value back to the PIC chip
ret

stop_beep:
  in al, 0x61    ; Read the PIC chip
  and al, 0x0FC  ; Clear bit 0 to disable the speaker
  out 0x61, al   ; Write the updated value back to the PIC chip
ret

; =========================================== DRAWING LINE ====================
; ax=x0
; bx=x1
; dl=y0,
; dh=y1,
; cl=col
; Spektre @ https://stackoverflow.com/questions/71390507/line-drawing-algorithm-in-assembly#71391899
draw_line:
  pusha       
    push    ax
    mov si,bx
    sub si,ax
    sub ah,ah
    mov al,dl
    mov bx,ax
    mov al,dh
    sub ax,bx
    mov di,ax
    mov ax,320
    sub dh,dh
    mul dx
    pop bx
    add ax,bx
    mov bp,ax
    mov ax,1
    mov bx,320
    cmp si,32768
    jb  .r0
    neg si
    neg ax
 .r0:    cmp di,32768
    jb  .r1
    neg di
    neg bx
 .r1:    cmp si,di
    ja  .r2
    xchg    ax,bx
    xchg    si,di
 .r2:    mov [.ct],si
 .l0:    mov word [es:bp], cx
    add bp,ax
    sub dx,di
    jnc .r3
    add dx,si
    add bp,bx
 .r3:    dec word [.ct]
    jnz .l0
    popa
    ret
 .ct:    dw  0


draw_vector:   
  pusha 
  .read_group:
    xor cx, cx
    mov cl, [si]
    cmp cl, 0x0
    jz .done

    inc si

    .read_line:
    push cx

    xor ax, ax
    mov al, [si]
    add ax, bp

    xor bx, bx
    mov bl, [si+2]
    add bx, bp
    mov dl, [si+1]
    mov dh, [si+3]
    mov cx, 0x1814  ; shadow color

    ; shake
    mov di, [_GAME_TICK_]
    shr di, 0x1
    add di, si
    and di, 0x2
    add ax, di
    sub bx, di
    add dx, di

    ; shadow
    call draw_line
    
    mov cx, 0x1e1f  ; white color
    sub ax, 0x1
    sub bx, 0x1
    sub dh, 0x2
    sub dl, 0x2    
    call draw_line

    ; double line
    dec cl
    dec ch
    inc ax
    inc bx
    call draw_line

    add si, 2
    pop cx
    loop .read_line
    add si, 2
    jmp .read_group
  .done:
  popa
  ret
