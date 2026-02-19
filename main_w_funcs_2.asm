.model tiny
.code
org 100h
LOCALS @@

CMD_LEN    equ 80h
CMD_TAIL   equ 81h

LINE_SEP   equ '%'
STYLE_SEP  equ '#'

VIDEO_SEG  equ 0B800h
COLOR      equ 07h            ; gray on black

ROW        equ 10d
COL        equ 15d
ROW_BYTES  equ 160            ; 80*2
START_DI   equ (ROW*80 + COL)*2

CH_TL      equ 0d           ;(левый  верхний угол)
CH_TR      equ 1d           ;(правый верхний угол)
CH_BL      equ 2d           ;(левый  нижний  угол)
CH_BR      equ 3d           ;(правый нижний  угол)
CH_H       equ 4d           ;(низ и верх)
CH_V       equ 5d          ;(право и лево)



start:
        call init_runtime

        call read_cmd_tail_trim_spaces      ; SI=ptr, CX=len, BX=len
        or   bx, bx
        jz   program_exit

        mov  word ptr [CMD_PTR_VAR], si
        mov  word ptr [CMD_LEN_VAR], cx


        mov  si, word ptr [CMD_PTR_VAR]
        mov  cx, word ptr [CMD_LEN_VAR]
        call measure_text         ; BX=max_len, BP=lines_count

        mov  word ptr [FRAME_W], bx
        mov  word ptr [FRAME_H], bp

        mov  dx, bx
        add  dx, dx
        mov  word ptr [FRAME_WB], dx        ; 2*FRAME_W


        call render_boxed_text

program_exit:
        call dos_exit

; ================================
; Entry:  -
; Exit:   DS - DS=CS
;         ES - ES=VIDEO_SEG
; Destr:  AX
; ================================
init_runtime proc
        push cs ; TODO - Лучши ли mov?
        pop  ds

        mov  ax, VIDEO_SEG
        mov  es, ax
        ret
init_runtime endp

; ================================
; Entry:  DS:PSP 
; Exit:   SI - адрес текста
;         CX - длина
;         BX - длина (копия CX)
; Destr:  AX, DI
; ================================
read_cmd_tail_trim_spaces proc
        xor  cx, cx
        mov  cl, byte ptr ds:[CMD_LEN]
        mov  si, CMD_TAIL

        call skip_leading_spaces
        call trim_trailing_spaces
        call parse_style_prefix

        mov  bx, cx
        ret
read_cmd_tail_trim_spaces endp

; ================================
; Entry:  DS:SI, CX - начало текста и длина
; Exit:   DS:SI, CX - возможно сдвинуты
;         FRAME_CHARS - выбранный стиль
; Exp:    После # есть символ
; Destr:  AX, BX, DX, AL
; ================================
parse_style_prefix proc
        cmp  cx, 2
        jb   @@done

        mov  al, byte ptr ds:[si]
        cmp  al, STYLE_SEP
        jne  @@done

        mov  al, byte ptr ds:[si+1]
        cmp  al, '1'
        jb   @@done
        cmp  al, '9'
        ja   @@done


        sub  al, '1'               ; style index
        xor  ah, ah
        shl  ax, 1                 ; word index
        mov  bx, ax

        mov  dx, word ptr [FRAME_STYLE_TABLE + bx]
        mov  word ptr [FRAME_CHARS], dx

        add  si, 2
        sub  cx, 2

        call skip_leading_spaces
        call trim_trailing_spaces

@@done:
        ret
parse_style_prefix endp

; ================================
; Entry:  DS:SI - начало 
;         CX - длина
; Exit:   CX - длина без пробелоы
; Destr:  AX, DI
; ================================
trim_trailing_spaces proc
        or   cx, cx
        jz   @@done

        mov  di, si
        add  di, cx
        dec  di

@@loop:
        or   cx, cx
        jz   @@done

        mov  al, byte ptr ds:[di]
        cmp  al, ' '
        jne  @@done

        dec  di
        dec  cx
        jmp  @@loop

@@done:
        ret
trim_trailing_spaces endp

; ================================
; Entry:  DS:SI, CX - текущая позиция и оставшаяся длина
; Exit:   SI, CX
; Destr:  AL
; ================================
skip_leading_spaces proc
@@skip:
        or   cx, cx
        jz   @@done

        mov  al, byte ptr ds:[si]
        cmp  al, ' '
        jne  @@done

        inc  si
        dec  cx
        jmp  @@skip
@@done:
        ret
skip_leading_spaces endp

; ================================
; Entry:  DS:SI, CX - начало текста и длинна
; Exit:   BX    - макс длина
;         BP    - кол-во строк
; Destr:  AX, DX, DI, SI, CX
; ================================
measure_text proc
        xor  bx, bx           ; max_len
        xor  bp, bp           ; lines_count

        or   cx, cx
        jz   @@done

@@next_line:
        inc  bp

        call skip_leading_spaces

        xor  di, di           ; cur_len
        xor  dx, dx           ; last_non_space_len

@@scan:
        or   cx, cx
        jz   @@end_line

        mov  al, byte ptr ds:[si]
        cmp  al, LINE_SEP
        je   @@end_line

        cmp  al, ' '
        je   @@space

        mov  dx, di
        inc  dx               ; last_symb = cur_len + 1

@@space:
        inc  di               ; cur_len++
        inc  si
        dec  cx
        jmp  @@scan

@@end_line:
        cmp  dx, bx
        jbe  @@max_ok
        mov  bx, dx
@@max_ok:
        ; убрать сеп
        or   cx, cx
        jz   @@done

        mov  al, byte ptr ds:[si]
        cmp  al, LINE_SEP
        jne  @@done

        inc  si
        dec  cx
        jmp  @@next_line

@@done:
        ret
measure_text endp

; ================================
; Entry:  CMD_PTR_VAR/CMD_LEN_VAR, FRAME_W/FRAME_H/FRAME_WB
; Exit:   -
; Destr:  AX, BX, CX, DX, DI, SI, BP
; ================================
render_boxed_text proc
        mov  di, START_DI
        sub  di, 2                          

        mov  bx, word ptr [FRAME_W]
        mov  bp, word ptr [FRAME_H]
        mov  dx, word ptr [FRAME_WB]

        call draw_frame_around_text

        mov  si, word ptr [CMD_PTR_VAR]
        mov  cx, word ptr [CMD_LEN_VAR]
        call print_text_inside_frame
        ret
render_boxed_text endp

; ================================
; Entry:  DI - аддрес места вывода текста
;         BX - макс ширина
;         DX - ширина в байтах
;         BP - высота
; Exit:   -
; Destr:  AX, CX, DI, SI
; ================================
draw_frame_around_text proc
        push di
        call draw_frame_top
        pop  di

        push di
        call draw_frame_sides
        pop  di

        push di
        call draw_frame_bottom
        pop  di

        ret
draw_frame_around_text endp

; ================================
; Entry:  DI - аддрес места вывода текста
;         BX - ширина
; Exit:   -
; Destr:  AX, CX, DI, SI
; ================================
draw_frame_top proc
        mov  ax,  ;TODO -
        sub  ax, ROW_BYTES
        mov  di, ax                          ; DI = top-left

        mov  ah, COLOR
        
        mov  si, [FRAME_CHARS]
        mov  al, byte ptr [si + CH_TL]
        mov  word ptr es:[di], ax

        mov  al, byte ptr [si + CH_H]
        add  di, 2
        mov  cx, bx
        jcxz @@no_h

@@top_h:
        mov  word ptr es:[di], ax
        add  di, 2
        loop @@top_h

@@no_h:
        mov  al, byte ptr [si + CH_TR]
        mov  word ptr es:[di], ax
        ret
draw_frame_top endp

; ================================
; Entry:  DI - аддрес места вывода текста
;         DX - ширина в байтах
;         BP - высота
; Exit:   -
; Destr:  AX, CX, DI, SI
; ================================
draw_frame_sides proc
        mov  ah, COLOR
        mov  si, [FRAME_CHARS]
        mov  al, byte ptr [si + CH_V]

        mov  cx, bp
        jcxz @@done

@@loop_row:
        mov  word ptr es:[di], ax            ; left side

        mov  si, di                          ; right side offset = di + 2 + dx
        add  si, 2
        add  si, dx
        mov  word ptr es:[si], ax

        add  di, ROW_BYTES
        loop @@loop_row

@@done:
        ret

draw_frame_sides endp

; ================================
; Entry:  DI - аддрес места вывода текста
;         BX - ширина
;         BP - высота 
; Exit:   -
; Destr:  AX, CX, DI, SI
; ================================
draw_frame_bottom proc
        mov  cx, bp
        jcxz @@at_bottom

@@move_down:
        add  di, ROW_BYTES
        loop @@move_down
@@at_bottom:
        mov  ah, COLOR
        mov  si, [FRAME_CHARS]
        mov  al, byte ptr [si + CH_BL]
        mov  word ptr es:[di], ax

        mov  al, byte ptr [si + CH_H]
        add  di, 2
        mov  cx, bx
        jcxz @@no_h

@@bot_h:
        mov  word ptr es:[di], ax
        add  di, 2
        loop @@bot_h

@@no_h:
        mov  al, byte ptr [si + CH_BR]
        mov  word ptr es:[di], ax
        ret
draw_frame_bottom endp

; ================================
; Entry:  DI - аддрес места вывода текста
;         BX - ширина
;         BP - высота
;         DS:SI, CX - хвост командной строки
; Exit:   -
; Destr:  AX, BX, CX, DX, DI, SI, BP
; ================================

print_text_inside_frame proc
        add  di, 2                           

        mov  bp, word ptr [FRAME_H]

@@line_loop:
        call parse_line_trim                 ; DX=line_start, AX=len, SI/CX -> конец строки

        call print_line_padded                

        call consume_line_separator           

        call advance_di_next_row             ; DI -> START_DI

        dec  bp
        jnz  @@line_loop
        ret
print_text_inside_frame endp

; ================================
; Entry:  DS:SI, CX - текущая позиция и оставшаяся длина
; Exit:   DX - аддрес слева
;         AX - длинна
;         SI, CX - продвинуты до конца строки
; Exp:    - 
; Destr:  AX, DX, DI, AL
; ================================
parse_line_trim proc
        push di;TODO - 
        push bx

        call skip_leading_spaces

        mov  dx, si                          ; DX = начало строки

        xor  di, di                          ; DI = cur_len
        xor  bx, bx                          ; AX = last_non_space_len

@@scan:
        or   cx, cx
        jz   @@done

        mov  al, byte ptr ds:[si]
        cmp  al, LINE_SEP
        je   @@done
        
        cmp  al, ' '
        je   @@space

        mov  bx, di
        inc  bx                              ; last_non_space_len = cur_len + 1

@@space:
        inc  di
        inc  si
        dec  cx
        jmp  @@scan

@@done:
        mov  ax, bx
        pop  bx
        pop  di
        ret
parse_line_trim endp


; ================================
; Entry:  ES:DI                   
;         DS:DX - начало строки
;         AX - длина
;         BX - ширина
; Exit:   DI - аддрес места конца вывода текста
; Destr:  AX, CX, DX, SI
; ================================
print_line_padded proc
        push si ;TODO -
        push cx ;TODO -
        push ax                              ; сохранить длинну

        mov  si, dx                          ; SI = line_start
        mov  cx, ax
        mov  ah, COLOR

        jcxz @@after_chars
@@print_chars:
        mov  al, byte ptr ds:[si]
        mov  word ptr es:[di], ax
        inc  si
        add  di, 2
        loop @@print_chars

@@after_chars:
        pop  dx                              ; DX = effective_len
        mov  cx, bx
        sub  cx, dx
        jcxz @@done

        mov  al, ' '
        mov  ah, COLOR
@@pad_loop:
        mov  word ptr es:[di], ax
        add  di, 2
        loop @@pad_loop

@@done:
        pop  cx
        pop  si
        ret
print_line_padded endp


; ================================
; Entry:  DS:SI, CX - аддрес конца строки и длинна
; Exit:   SI, CX                  
; Destr:  AL
; ================================
consume_line_separator proc
        or   cx, cx
        jz   @@done

        mov  al, byte ptr ds:[si]
        cmp  al, LINE_SEP
        jne  @@done

        inc  si
        dec  cx
@@done:
        ret
consume_line_separator endp


; ================================
; Entry:  DI - аддрес места вывода строки
; Exit:   DI - START_DI следующей строки
; Exp:    FRAME_WB = 2*FRAME_W
; Destr:  AX
; ================================
advance_di_next_row proc
        sub  di, word ptr [FRAME_WB]
        add  di, ROW_BYTES
        ret
advance_di_next_row endp

; ================================
; Entry:  -
; Exit:   -
; Destr:  AX
; ================================
dos_exit proc
        mov  ax, 4C00h
        int  21h
        ret
dos_exit endp


.data

CMD_PTR_VAR dw 0
CMD_LEN_VAR dw 0

FRAME_W     dw 0
FRAME_H     dw 0
FRAME_WB    dw 0


FRAME_STYLE1 db 0C9h, 0BBh, 0C8h, 0BCh, 0CDh, 0BAh ; ╔ ╗ ╚ ╝ ═ ║ ;TODO - Как перенести наверх
FRAME_STYLE2 db '+', '+', '+', '+', '-', '|'       ; + + + + - |
FRAME_STYLE3 db '#', '#', '#', '#', '#', '#'  ; # # # # # #

FRAME_STYLE_TABLE dw offset FRAME_STYLE1
                  dw offset FRAME_STYLE2
                  dw offset FRAME_STYLE3
                  dw offset FRAME_STYLE1
                  dw offset FRAME_STYLE1
                  dw offset FRAME_STYLE1
                  dw offset FRAME_STYLE1
                  dw offset FRAME_STYLE1
                  dw offset FRAME_STYLE1

FRAME_CHARS  dw FRAME_STYLE1

end start

;TODO - Как относиться к оптимизации?  У меня 2 прохода. потому что мне показалось, что так будет удобнее писать
