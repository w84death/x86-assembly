; GAME10 - Mysteries of the Forgotten Isles
; File name: tunes.asm
; Description: Music and sound effects data
; Size: 235 bytes
;
; Size category: 4096 bytes / 4KB
; Bootloader: 512 bytes
; Author: Krzysztof Krystian Jankowski
; Web: smol.p1x.in/assembly/forgotten-isles/
; License: MIT


tune_intro:
db 5   ,7   ,8   ,7  ,5   ,8   ,10  ,8  ,7   ,5   ,7   ,8  ,7   ,5   ,3   ,5
db 8   ,10  ,12  ,10 ,8   ,7   ,8   ,10 ,12  ,10  ,8   ,7  ,8   ,5   ,3   ,5
db 10  ,12  ,14  ,12 ,10  ,8   ,10  ,12 ,14  ,12  ,10  ,8  ,7   ,5   ,7   ,8
db 12  ,14  ,15  ,14 ,12  ,10  ,12  ,14 ,15  ,14  ,12  ,10 ,8   ,7   ,8   ,10
db 5   ,7   ,8   ,7  ,5   ,8   ,10  ,8  ,7   ,5   ,7   ,8  ,7   ,5   ,3   ,5
db 8   ,10  ,12  ,10 ,8   ,7   ,8   ,10 ,12  ,10  ,8   ,7  ,8   ,5   ,3   ,5
db 10  ,12  ,14  ,12 ,10  ,8   ,10  ,12 ,14  ,12  ,10  ,8  ,7   ,5   ,7   ,8
db 12  ,14  ,15  ,14 ,12  ,10  ,12  ,14 ,15  ,14  ,12  ,10 ,8   ,7   ,8   ,10
db 0

tune_end:
db 12, 10, 8,  10, 7,  6 , 5,  6
db 8 , 7 , 5,  4 , 3,  5 , 6,  4
db 6 , 5 , 4,  3 , 2,  3 , 5,  2
db 5 , 4 , 3,  2 , 1,  2 , 1,  1
db 12, 10, 8,  10, 7,  6 , 5,  6
db 8 , 7 , 5,  4 , 3,  5 , 6,  4
db 0

tune_win:
db 13, 15, 17, 15, 13, 12, 10,  12
db 13, 15, 17, 15, 13, 19, 17,  15
db 12, 14, 16, 14, 12, 15, 13,  12
db 10, 12, 14, 12, 10, 9 , 8 ,  10
db 13, 15, 17, 15, 13, 12, 10,  12
db 13, 15, 17, 15, 13, 19, 17,  15
db 12, 14, 16, 14, 12, 15, 13,  12
db 10, 12, 14, 12, 10, 9 , 8 ,  10
db 0

BEEP_BITE equ 3
BEEP_PICK equ 15
BEEP_PUT equ 20
BEEP_GOLD equ 5
BEEP_STEP equ 25
BEEP_WEB equ 30
