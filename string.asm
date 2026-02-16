.model tiny
.code
org 100h

CMD_LEN  equ 80h        
CMD_TAIL equ 81h          

VIDEO_SEG equ 0B800h
COLOR     equ 07h         ; gray on black

ROW equ 10d
COL equ 15d

START_DI equ (ROW*80 + COL)*2

start:
        mov ax, VIDEO_SEG
        mov es, ax

        mov di, START_DI  ;start offset

        xor cx, cx
        mov cl, byte ptr ds:[CMD_LEN]     ; CX = tail_len
        jcxz done                         ;if 0 args

        mov si, CMD_TAIL + 1              ; SI = tail start - ' '
        dec cx

print_loop:
        mov al, byte ptr ds:[si]          ; AL = curr symb

        mov ah, COLOR                     ; AH = color
        mov word ptr es:[di], ax          ; write symb to video

        inc si
        add di, 2
        loop print_loop                   ; CX--, if CX != 0 -> print_loop

done:
        mov ax, 4C00h
        int 21h                           ; DOS (Disk Operating System) exit

end start
