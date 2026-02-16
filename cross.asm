.model tiny
.code
org 100h

VIDEO_ADDRESS equ 0B800h
ROW_BYTES     equ 160          ; 80*2

CROSS_SIZE    equ 5d
CROSS_HALF    equ CROSS_SIZE/2d

CENTER_X      equ 10d
CENTER_Y      equ 15d

COLOR         equ 07h          ; gray on black
CH_VERT       equ 0BAh         ; '||' 
CH_HORZ       equ 0CDh         ; '=' 
CH_CROSS      equ 0CEh         ; cross 

start:
        mov ax, VIDEO_ADDRESS
        mov es, ax

        mov di, (CENTER_X * 2) + ((CENTER_Y - CROSS_HALF) * ROW_BYTES) ; start pos
        mov cx, CROSS_SIZE                                             ; init counter
        mov ax, (COLOR shl 8) + CH_VERT                                ; init symb

v_loop:
        mov word ptr es:[di], ax
        add di, ROW_BYTES
        loop v_loop


        mov di, (CENTER_Y * ROW_BYTES) + ((CENTER_X - CROSS_HALF) * 2) 
        mov cx, CROSS_SIZE
        mov ax, (COLOR shl 8) + CH_HORZ

h_loop:
        mov word ptr es:[di], ax
        add di, 2
        loop h_loop


        mov di, (CENTER_X * 2) + (CENTER_Y * ROW_BYTES)
        mov word ptr es:[di], (COLOR shl 8) + CH_CROSS

        mov ax, 4C00h
        int 21h             

end start
