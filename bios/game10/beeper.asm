; Simplified Note Sequencer (Counter-Based, 50Hz Loop)


org 0x7C00
use16 

start:
    cli                 ; Disable interrupts
    xor ax, ax
    mov ds, ax
    mov es, ax

; Data for Notes (Frequency, Duration in 50Hz loop iterations)
notes:
    dw 440,100 ; A4 for 2 seconds
    dw 523, 75  ; C5 for 1.5 seconds
    dw 659, 50  ; E5 for 1 second
notes_end:

; Variables
current_note equ 0x100 ; Memory address for current note pointer
note_counter equ 0x102 ; Memory address for note duration counter
_TICK_ equ 1Ah ; BIOS interrupt for reading system timer

; Initialization (call once at game start)
init_note_sequencer:
    mov word [current_note], notes ; Set current note to first note
    mov dx, [notes + 2] ; Load duration of first note into counter
    mov [note_counter], dx

; One-time initialization for PC Speaker (mode 2, binary, LSB/MSB for Counter 0)
init_pc_speaker:
    mov al, 0xB6 ; 1011 0110 (Mode 2, LSB/MSB, Counter 0)
    out 0x43, al

game_loop:

    
reset_notes:
    mov word [current_note], notes ; Reset to first note
    mov dx, [notes + 2] ; Load first note's duration
    mov [note_counter], dx ; Update note counter
    jmp play_note ; Play first note again

; =========================================== GAME TICK ========================
wait_for_tick:
    xor ax, ax          ; Function 00h: Read system timer counter
    int _TICK_          ; Returns tick count in CX:DX
    mov bx, dx          ; Store the current tick count
.wait_loop:
    int _TICK_          ; Read the tick count again
    cmp dx, bx
    je .wait_loop       ; Loop until the tick count changes

; =========================================== ESC OR LOOP ======================

  in al, 0x60                  ; Read keyboard
  dec al                      ; Decrement AL (esc is 1, after decrement is 0)
  jnz game_loop               ; If not zero, loop again

; =========================================== TERMINATE PROGRAM ================

  exit:
    mov ax, 0x4c00
    int 0x21
ret                       ; Return to BIOS/DOS

; Main Note Sequencer Logic (call every 50Hz loop iteration)
play_note:
    ; Check if note duration has expired
    dec word [note_counter] ; Decrement note counter
    call switch_note ; If zero, switch to next note

    ; Play current note (output frequency to PC speaker)
    mov si, [current_note] ; Load current note address
    mov ax, [si] ; Load frequency of current note
    out 0x42, al ; Output low byte of frequency
ret

switch_note:
    ; Disable current note (optional, or just load new frequency)
    mov ax, 1
    out 0x42, al

    ; Move to next note
    mov si, [current_note] ; Load current note address
    add si, 4 ; Skip to next note (freq(2) + duration(2))
    mov [current_note], si ; Update current note pointer
    cmp si, notes_end ; Check if end of notes list
    jge reset_notes ; If end, reset to start

    ; Load new note's duration and play
    mov dx, [si + 2] ; Load new duration
    mov [note_counter], dx ; Update note counter
ret
    
    times 507 - ($ - $$) db 0   ; Pad to 510 bytes
db "P1X"                    ; Use HEX viewer to see P1X at the end of binary
dw 0xAA55                   ; Boot signature
