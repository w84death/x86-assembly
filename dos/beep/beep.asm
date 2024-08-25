ChatGPT4o

.model small
.stack 100h
.data
    frequency dw 440      ; Frequency of the sound (440 Hz for A4 note)
    duration dw 1000      ; Duration of the sound in milliseconds

.code
main:
    ; Initialize the data segment
    mov ax, @data
    mov ds, ax

    ; Set the speaker frequency
    mov ax, 1193180      ; Base frequency for the PC speaker
    div frequency         ; Divide to get the divisor
    mov dx, ax           ; Store the divisor in DX

    ; Set the speaker frequency
    mov dx, 0x43         ; Control word port
    mov al, 0xB6         ; Set the mode to square wave generator
    out dx, al           ; Send control word

    mov dx, 0x42         ; Channel 2 data port
    mov al, dl           ; Low byte of the divisor
    out dx, al           ; Send low byte

    mov al, dh           ; High byte of the divisor
    out dx, al           ; Send high byte

    ; Turn on the speaker
    in al, 0x61          ; Read the current state of the speaker
    or al, 3             ; Set bit 0 and bit 1 to turn on the speaker
    out 0x61, al         ; Write back to the port

    ; Delay loop for the duration
    mov cx, duration
    call delay

    ; Turn off the speaker
    in al, 0x61          ; Read the current state of the speaker
    and al, 0xFC         ; Clear bit 0 and bit 1 to turn off the speaker
    out 0x61, al         ; Write back to the port

    ; Exit program
    mov ax, 4C00h        ; DOS terminate program
    int 21h

; Simple delay routine
delay:
    push cx
    push dx
    mov dx, 0FFFFh       ; Set up a maximum delay
delay_loop:
    nop                   ; No operation (do nothing)
    loop delay_loop       ; Loop until CX is zero
    pop dx
    pop cx
    ret

end main




LLAMA

; Set up the PIT to generate a 1 kHz frequency
mov al, 0xB6 ; 10110110b (binary) - 1 kHz frequency
out 43h, al ; Send the command to the PIT

; Set up the PIT to generate a square wave on the PC speaker
mov al, 0x03 ; 00000011b (binary) - enable speaker and set to 2 MHz
out 42h, al ; Send the command to the PIT

; Play the sound for 1 second
mov cx, 0x1000 ; 1 second
loop $-1

; Disable the speaker
mov al, 0x00 ; 00000000b (binary) - disable speaker
out 42h, al ; Send the command to the PIT


CLAUDE

.model small
.stack 100h

.code
start:
    ; Set the speaker frequency
    mov al, 0B6h  ; Command to set the speaker frequency
    out 43h, al   ; Write the command to the PIT chip
    mov ax, 2715  ; Frequency value for 440 Hz
    out 42h, al   ; Write the low byte of the frequency value
    mov al, ah
    out 42h, al   ; Write the high byte of the frequency value

    ; Enable the speaker
    in al, 61h    ; Read the PIC chip
    or al, 03h    ; Set bit 0 to enable the speaker
    out 61h, al   ; Write the updated value back to the PIC chip

    ; Wait for 1 second
    mov cx, 18    ; 18 ticks per second
    mov dx, 0     ; Initialize the delay counter
wait_loop:
    dec cx
    jnz wait_loop
    dec dx
    jnz wait_loop

    ; Disable the speaker
    in al, 61h    ; Read the PIC chip
    and al, 0FCh  ; Clear bit 0 to disable the speaker
    out 61h, al   ; Write the updated value back to the PIC chip

    ; Exit the program
    mov ah, 4Ch
    int 21h
end start



