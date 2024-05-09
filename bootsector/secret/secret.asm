org 7C00h             ; Set origin to where BIOS loads
jmp start             ; Jump to the start of our code

OEMlabel    db "MYFLOPPY"  ; OEM label
BytesPerSector  dw 512    ; Bytes per sector
SectorsPerCluster db 1    ; Sectors per cluster
ReservedSectors  dw 1    ; Reserved sectors
NumberOfFATs  db 2    ; Number of FATs
RootDirEntries  dw 224    ; Root directory entries
TotalSectors    dw 2880   ; Total sectors
MediaDescriptor db 0xF0   ; Media descriptor
SectorsPerFAT    dw 9    ; Sectors per FAT
SectorsPerTrack  dw 18    ; Sectors per track
Sides       dw 2    ; Number of sides
HiddenSectors   dd 0    ; Number of hidden sectors
LargeSectors    dd 0    ; Large sector count
DriveNo     dw 0    ; Drive number
Signature    db 0x29   ; Signature
VolumeID    dd 0        ; Volume ID
VolumeLabel   db "MYFLOPPY " ; Volume label
FileSystem   db "FAT12   "   ; File system type

start:
    ; Display secret message
    mov ah, 0Eh    ; BIOS function to display character
    mov al, 'S'    ; Secret message character
    int 10h        ; Call BIOS interrupt to display character
    mov al, 'e'
    int 10h
    mov al, 'c'
    int 10h
    mov al, 'r'
    int 10h
    mov al, 'e'
    int 10h
    mov al, 't'
    int 10h
    mov al, ' '
    int 10h
    mov al, 'D'
    int 10h
    mov al, 'a'
    int 10h
    mov al, 't'
    int 10h
    mov al, 'a'
    int 10h

    jmp $          ; Loop indefinitely

times 510-($-$$) db 0 ; Pad rest of boot sector with 0s
dw 0AA55h            ; Boot signature