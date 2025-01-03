; GAME10 - Mysteries of the Forgotten Isles
; File name: palettes.asm
; Description: Color palette sets
; Size: 72 bytes
;
; Size category: 4096 bytes / 4KB
; Bootloader: 512 bytes
; Author: Krzysztof Krystian Jankowski
; Web: smol.p1x.in/assembly/forgotten-isles/
; License: MIT

; =========================================== COLOR PALETTES ===================
; Set of four colors per palette. 0x00 is transparency; use 0x10 for black.

PaletteSets:
db 0x00, 0x34, 0x16, 0x1a   ; 0x0 Grays
db 0x00, 0xba, 0x06, 0x42   ; 0x1 Indie top
db 0x00, 0xba, 0xbd, 0x72   ; 0x2 Indie bottom
db 0x34, 0x35, 0x00, 0x00   ; 0x3 Bridge
db 0x00, 0xd1, 0x73, 0x06   ; 0x4 Chest
db 0x00, 0x4a, 0x45, 0x2e   ; 0x5 Terrain 1 - shore
db 0x4a, 0x48, 0x2e, 0x46   ; 0x6 Terrain 2 - in  land
db 0x00, 0x72, 0x78, 0x02   ; 0x7 Palm & Bush
db 0x00, 0x27, 0x2a, 0x2b   ; 0x8 Snake
db 0x00, 0x2b, 0x2c, 0x5b   ; 0x9 Gold Coin
db 0x00, 0x16, 0x17, 0x19   ; 0xa Rock
db 0x00, 0x1b, 0x1d, 0x1e   ; 0xb Sail
db 0x00, 0x14, 0x16, 0x1f   ; 0xc Spider
db 0x00, 0x1c, 0x1e, 0x1f   ; 0xd Web
db 0x00, 0x04, 0x0c, 0x1f   ; 0x0e Crab
db 0x00, 0x71, 0x06, 0x2a   ; 0x0f Chest
db 0x00, 0x00, 0x75, 0x00   ; 0x10 Shadow
