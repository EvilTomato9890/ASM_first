.model tiny
.code
org 100h

CMD_LEN    equ 80h
CMD_TAIL   equ 81h

VIDEO_SEG  equ 0B800h
COLOR      equ 07h            ; gray on black

ROW        equ 10d
COL        equ 15d
ROW_BYTES  equ 160            ; 80*2 bytes per text row
START_DI   equ (ROW*80 + COL)*2

; Box drawing chars in CP437 (Code Page 437)
CH_TL      equ 0C9h           ; ╔
CH_TR      equ 0BBh           ; ╗
CH_BL      equ 0C8h           ; ╚
CH_BR      equ 0BCh           ; ╝
CH_H       equ 0CDh           ; ═
CH_V       equ 0BAh           ; ║

start:
        mov ax, VIDEO_SEG
        mov es, ax

        xor cx, cx
        mov cl, byte ptr ds:[CMD_LEN]  ; DS (Data Segment): PSP (Program Segment Prefix) tail length
        jcxz  cx0_1
        jmp   short cx1_1
cx0_1:  jmp   done
cx1_1:

        mov si, CMD_TAIL + 1           ; skip leading space
        dec cx                         ; CX = text length

        mov bx, cx                     ; BX = text length

        mov di, START_DI
        sub di, 2                      ; DI = cell left from text start
        mov dx, bx
        add dx, dx                     ; DX = text_len * 2

        ; TOP border
        mov ax, di
        sub ax, ROW_BYTES
        mov di, ax                     ; DI = top-left corner position

        mov ah, COLOR
        mov al, CH_TL                  ; ╔
        mov word ptr es:[di], ax

        mov ah, COLOR
        mov al, CH_H                   ; ═
        mov cx, bx
        add di, 2
top_h:
        mov word ptr es:[di], ax
        add di, 2
        loop top_h

        mov ah, COLOR
        mov al, CH_TR                  ; ╗
        mov word ptr es:[di], ax

        ; SIDE borders
        mov ah, COLOR
        mov al, CH_V                   ; ║

        mov di, START_DI
        sub di, 2
        mov word ptr es:[di], ax       ; left side

        mov di, START_DI
        add di, dx
        mov word ptr es:[di], ax       ; right side (cell after text)

        ; BOTTOM border
        mov di, START_DI
        sub di, 2
        add di, ROW_BYTES

        mov ah, COLOR
        mov al, CH_BL                  ; ╚
        mov word ptr es:[di], ax

        mov ah, COLOR
        mov al, CH_H                   ; ═
        mov cx, bx
        add di, 2
bot_h:
        mov word ptr es:[di], ax
        add di, 2
        loop bot_h

        mov ah, COLOR
        mov al, CH_BR                  ; ╝
        mov word ptr es:[di], ax

        ; Print text
        mov di, START_DI
        mov cx, bx
print_loop:
        mov al, byte ptr ds:[si]
        mov ah, COLOR
        mov word ptr es:[di], ax
        inc si
        add di, 2
        loop print_loop

end start
