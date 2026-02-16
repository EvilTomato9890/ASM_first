.model tiny
.code
org 100h

CMD_LEN  equ 80h      
CMD_TAIL equ 81h      

start:
        xor cx, cx
        mov cl, byte ptr DS:CMD_LEN    ; CX = tail len

        mov si, CMD_TAIL              ; SI = first dymb

        inc si                       ; space skip
        dec cx

print_loop:
        mov dl, [si]                 ; DL = curr symb
        mov ah, 02h                  ; print symb
        int 21h
        inc si                       ; increase index
        loop print_loop               ; CX--, if CX != 0 -> print_loop

        mov ax, 4C00h
        int 21h

end start
