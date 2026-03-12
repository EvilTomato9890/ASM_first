.model tiny
.code
org 100h
LOCALS @@
;.JUMPS
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
CH_TR      equ 2d           ;(правый верхний угол)
CH_BL      equ 4d           ;(левый  нижний  угол)
CH_BR      equ 6d           ;(правый нижний  угол)
CH_H       equ 8d           ;(низ и верх)
CH_V       equ 10d          ;(право и лево)



start:
        call InitRuntime

        call ReadCmdTailTrimSpaces      ; SI=ptr, CX=len, BX=len
        or   bx, bx
        jz   program_exit

        mov  word ptr [CMD_PTR_VAR], si
        mov  word ptr [CMD_LEN_VAR], cx


        mov  si, word ptr [CMD_PTR_VAR]
        mov  cx, word ptr [CMD_LEN_VAR]
        call MeasureText         ; BX=max_len, BP=lines_count

        mov  word ptr [FRAME_W], bx
        mov  word ptr [FRAME_H], bp

        mov  dx, bx
        add  dx, dx
        mov  word ptr [FRAME_WB], dx        ; 2*FRAME_W


        call RenderBoxedText

program_exit:
        call DosExit

; ================================
; Desc: Инициализирует DS и ES для работы с кодом и видеопамятью.
; Entry:  -
; Exit:   DS - DS=CS
;         ES - ES=VIDEO_SEG
; Destr:  AX
; ================================
InitRuntime proc
        push cs ;; TODO - Лучши ли mov?
        pop  ds

        mov  ax, VIDEO_SEG
        mov  es, ax
        ret
InitRuntime endp

; ================================
; Desc: Читает хвост команды, обрезает пробелы и разбирает стиль рамки.
; Entry:  DS:PSP 
; Exit:   SI - адрес текста
;         CX - длина
;         BX - длина (копия CX)
; Destr:  AX, DI
; ================================
ReadCmdTailTrimSpaces proc
        xor  cx, cx
        mov  cl, byte ptr ds:[CMD_LEN]
        mov  si, CMD_TAIL

        call SkipLeadingSpaces
        call TrimTrailingSpaces
        call ParseStylePrefix

        mov  bx, cx
        ret
ReadCmdTailTrimSpaces endp

; ================================
; Desc: Обрабатывает префикс #N и выбирает ыенду.
; Entry:  DS:SI, CX - начало текста и длина
; Exit:   DS:SI, CX - возможно сдвинуты
;         FRAME_CHARS - выбранный стиль
; Exp:    После # есть символ
; Destr:  AX, BX, DX, AL
; ================================
ParseStylePrefix proc
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

        add  si, 2
        sub  cx, 2

        cmp  al, '9'
        je   @@custom_style


        sub  al, '1'               ; style index
        xor  ah, ah
        shl  ax, 1                 ; word index
        mov  bx, ax

        mov  dx, word ptr [FRAME_STYLE_TABLE + bx]
        mov  word ptr [FRAME_CHARS], dx
        jmp  @@trim_text

@@custom_style:
        call ParseStyle9CustomChars

@@trim_text:
        call SkipLeadingSpaces
        call TrimTrailingSpaces

@@done:
        ret
ParseStylePrefix endp

; ================================
; Desc: Для префикса #9 считывает 6 символов рамки из хвоста.
;       Порядок: TL TR BL BR H V.
; Entry: DS:SI, CX - позиция сразу после "#9"
; Exit:  При успехе: SI/CX сдвинуты после 6 символов, FRAME_CHARS=custom
;        При ошибке: SI/CX восстановлены
; Destr: AX, BX, DI
; ================================
ParseStyle9CustomChars proc
        push si
        push cx

        call SkipLeadingSpaces
        cmp  cx, 6
        jb   @@restore

        mov  di, offset FRAME_STYLE9_CUSTOM
        mov  bx, 6

@@copy_loop:
        mov  al, byte ptr ds:[si]
        mov  ah, COLOR
        mov  word ptr [di], ax
        add  di, 2
        inc  si
        dec  cx
        dec  bx
        jnz  @@copy_loop

        mov  word ptr [FRAME_CHARS], offset FRAME_STYLE9_CUSTOM
        add  sp, 4
        ret

@@restore:
        pop  cx
        pop  si
        ret
ParseStyle9CustomChars endp

; ================================
; Desc: Удаляет пробелы в конце текста.
; Entry:  DS:SI - начало 
;         CX - длина
; Exit:   CX - длина без пробелоы
; Destr:  AX, DI
; ================================
TrimTrailingSpaces proc
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
TrimTrailingSpaces endp

; ================================
; Desc: Пропускает ведущие пробелы и сдвигает SI/CX на первый символ.
; Entry:  DS:SI, CX - текущая позиция и оставшаяся длина
; Exit:   SI, CX
; Destr:  AL
; ================================
SkipLeadingSpaces proc
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
SkipLeadingSpaces endp

; ================================
; Desc: Считает число строк и максимальную длину строки без хвостовых пробелов.
; Entry:  DS:SI, CX - начало текста и длинна
; Exit:   BX    - макс длина
;         BP    - кол-во строк
; Destr:  AX, DX, DI, SI, CX
; ================================
MeasureText proc
        xor  bx, bx           ; max_len
        xor  bp, bp           ; lines_count

        or   cx, cx
        jz   @@done

@@next_line:
        inc  bp

        call SkipLeadingSpaces

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
MeasureText endp

; ================================
; Desc: Рисует рамку нужного размера и выводит внутри исходный текст.
; Entry:  CMD_PTR_VAR/CMD_LEN_VAR, FRAME_W/FRAME_H/FRAME_WB
; Exit:   -
; Destr:  AX, BX, CX, DX, DI, SI, BP
; ================================
RenderBoxedText proc
        mov  di, START_DI
        sub  di, 2                          

        mov  bx, word ptr [FRAME_W]
        mov  bp, word ptr [FRAME_H]
        mov  dx, word ptr [FRAME_WB]

        call DrawFrameAroundText

        mov  si, word ptr [CMD_PTR_VAR]
        mov  cx, word ptr [CMD_LEN_VAR]
        call PrintTextInsideFrame
        ret
RenderBoxedText endp

; ================================
; Desc: Вызывает отрисовку верхней, боковых и нижней частей рамки.
; Entry:  DI - аддрес места вывода текста
;         BX - макс ширина
;         DX - ширина в байтах
;         BP - высота
; Exit:   -
; Destr:  AX, CX, SI
; ================================
DrawFrameAroundText proc
        push di
        call DrawFrameTop
        pop  di

        push di
        call DrawFrameSides
        pop  di

        push di
        call DrawFrameBottom
        pop  di

        ret
DrawFrameAroundText endp

; ================================
; Desc: Рисует верхнюю границу рамки с углами и горизонтальной линией.
; Entry:  DI - аддрес места вывода текста
;         BX - ширина
; Exit:   -
; Destr:  AX, CX, DI, SI
; ================================
DrawFrameTop proc
        sub  di, ROW_BYTES                          ; DI = top-left

        mov  si, [FRAME_CHARS]
        mov  ax, word ptr [si + CH_TL]
        mov  dx, word ptr [si + CH_H]
        mov  si, word ptr [si + CH_TR]

        push bx
        push bp

        mov  cx, bx
        mov  bx, 1
        mov  bp, 1
        call DrawFrameRow

        pop  bp
        pop  bx
        ret
DrawFrameTop endp

; ================================
; Desc: Рисует левую и правую боковые границы рамки по высоте.
; Entry:  DI - аддрес места вывода текста
;         DX - ширина в байтах
;         BP - высота
; Exit:   -
; Destr:  AX, CX, DI, SI
; ================================
DrawFrameSides proc
        mov  si, [FRAME_CHARS]
        mov  ax, word ptr [si + CH_V]
        mov  si, ax

        mov  dx, (COLOR shl 8) + ' '

        push bx
        push bp

        mov  cx, word ptr [FRAME_H]
        jcxz @@done

@@loop_row:
        push cx
        push di

        mov  bx, 1
        mov  cx, word ptr [FRAME_W]
        mov  bp, 1
        call DrawFrameRow

        pop  di
        add  di, ROW_BYTES
        pop  cx
        loop @@loop_row

@@done:
        pop  bp
        pop  bx
        ret

DrawFrameSides endp

; ================================
; Desc: Рисует нижнюю границу рамки с углами и горизонтальной линией.
; Entry:  DI - аддрес места вывода текста
;         BX - ширина
;         BP - высота 
; Exit:   -
; Destr:  AX, CX, DI, SI
; ================================
DrawFrameBottom proc
        mov  cx, word ptr [FRAME_H]
        jcxz @@at_bottom

@@move_down:
        add  di, ROW_BYTES
        loop @@move_down
@@at_bottom:
        mov  si, [FRAME_CHARS]
        mov  ax, word ptr [si + CH_BL]
        mov  dx, word ptr [si + CH_H]
        mov  si, word ptr [si + CH_BR]

        push bx
        push bp

        mov  cx, bx
        mov  bx, 1
        mov  bp, 1
        call DrawFrameRow

        pop  bp
        pop  bx
        ret
DrawFrameBottom endp

; ================================
; Desc: Рисует строку рамки из трёх сегментов: левый, средний, правый.
; Entry: ES:DI - адрес вывода
;        AX, BX - левый символ и его количество
;        DX, CX - средний символ и его количество
;        SI, BP - правый символ и его количество
; Exit:  DI - адрес конца нарисованной строки
; Destr: CX
; ================================
DrawFrameRow proc
@@draw_left:
        or   bx, bx
        jz   @@draw_mid
        mov  word ptr es:[di], ax
        add  di, 2
        dec  bx
        jmp  @@draw_left

@@draw_mid:
        jcxz @@draw_right
@@draw_mid_loop:
        mov  word ptr es:[di], dx
        add  di, 2
        loop @@draw_mid_loop

@@draw_right:
        or   bp, bp
        jz   @@done
        mov  word ptr es:[di], si
        add  di, 2
        dec  bp
        jmp  @@draw_right

@@done:
        ret
DrawFrameRow endp

; ================================
; Desc: Построчно разбирает и печатает текст внутри рамки.
; Entry:  DI - аддрес места вывода текста
;         BX - ширина
;         BP - высота
;         DS:SI, CX - хвост командной строки
; Exit:   -
; Destr:  AX, BX, CX, DX, DI, SI, BP
; ================================

PrintTextInsideFrame proc
        add  di, 2                           

        mov  bp, word ptr [FRAME_H]

@@line_loop:
        call ParseLineTrim                 ; DX=line_start, AX=len, SI/CX -> конец строки

        call PrintLinePadded                

        call ConsumeLineSeparator           

        call AdvanceDiNextRow             ; DI -> START_DI

        dec  bp
        jnz  @@line_loop
        ret
PrintTextInsideFrame endp

; ================================
; Desc: Выделяет текущую строку и вычисляет длину без хвостовых пробелов.
; Entry:  DS:SI, CX - текущая позиция и оставшаяся длина
; Exit:   DX - аддрес слева
;         AX - длинна
;         SI, CX - продвинуты до конца строки
; Exp:    - 
; Destr:  AX, DX, AL
; ================================
ParseLineTrim proc
        push di
        push bx

        call SkipLeadingSpaces

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
ParseLineTrim endp


; ================================
; Desc: Центрирует строку в ширине рамки и добивает пробелами слева/справа.
; Entry:  ES:DI                   
;         DS:DX - начало строки
;         AX - длина
;         BX - ширина
; Exit:   DI - аддрес места конца вывода текста
; Destr:  AX, DX
; ================================
PrintLinePadded proc
        push si 
        push cx 
        push bp
        push dx                              ; line_start
        push ax                              ; effective_len

        mov  cx, bx
        sub  cx, ax                          ; total_pad = width - len
        mov  bp, cx
        shr  cx, 1                           ; left_pad = total_pad / 2
        mov  dx, bp
        sub  dx, cx                          ; right_pad = total_pad - left_pad

        mov  al, ' '
        mov  ah, COLOR
        jcxz @@after_left_pad
@@left_pad_loop:
        mov  word ptr es:[di], ax
        add  di, 2
        loop @@left_pad_loop

@@after_left_pad:
        pop  ax                              ; AX = effective_len
        pop  si                              ; SI = line_start
        mov  cx, ax
        jcxz @@after_chars
@@print_chars:
        mov  al, byte ptr ds:[si]
        mov  ah, COLOR
        mov  word ptr es:[di], ax
        inc  si
        add  di, 2
        loop @@print_chars

@@after_chars:
        mov  cx, dx
        jcxz @@done
        mov  al, ' '
        mov  ah, COLOR
@@right_pad_loop:
        mov  word ptr es:[di], ax
        add  di, 2
        loop @@right_pad_loop

@@done:
        pop  bp
        pop  cx
        pop  si
        ret
PrintLinePadded endp


; ================================
; Desc: Пропускает символ разделителя строки, если он есть.
; Entry:  DS:SI, CX - аддрес конца строки и длинна
; Exit:   SI, CX                  
; Destr:  AL
; ================================
ConsumeLineSeparator proc
        or   cx, cx
        jz   @@done

        mov  al, byte ptr ds:[si]
        cmp  al, LINE_SEP
        jne  @@done

        inc  si
        dec  cx
@@done:
        ret
ConsumeLineSeparator endp


; ================================
; Desc: Переводит указатель вывода на начало следующей строки внутри рамки.
; Entry:  DI - аддрес места вывода строки
; Exit:   DI - START_DI следующей строки
; Exp:    FRAME_WB = 2*FRAME_W
; Destr:  AX
; ================================
AdvanceDiNextRow proc
        sub  di, word ptr [FRAME_WB]
        add  di, ROW_BYTES
        ret
AdvanceDiNextRow endp

; ================================
; Desc: Завершает программу через DOS (int 21h, AH=4Ch).
; Entry:  -
; Exit:   -
; Destr:  AX
; ================================
DosExit proc
        mov  ax, 4C00h
        int  21h
        ret
DosExit endp


.data

CMD_PTR_VAR dw 0
CMD_LEN_VAR dw 0

FRAME_W     dw 0
FRAME_H     dw 0
FRAME_WB    dw 0


FRAME_STYLE1 dw (07h shl 8) + 0C9h ; ╔
             dw (07h shl 8) + 0BBh ; ╗
             dw (07h shl 8) + 0C8h ; ╚
             dw (07h shl 8) + 0BCh ; ╝
             dw (07h shl 8) + 0CDh ; ═
             dw (07h shl 8) + 0BAh ; ║


FRAME_STYLE2 dw (07h shl 8) + '+' 
             dw (07h shl 8) + '+' 
             dw (07h shl 8) + '+' 
             dw (07h shl 8) + '+' 
             dw (07h shl 8) + '-' 
             dw (07h shl 8) + '|'       

FRAME_STYLE3 dw (07h shl 8) + '#' 
             dw (07h shl 8) + '#' 
             dw (07h shl 8) + '#' 
             dw (07h shl 8) + '#' 
             dw (07h shl 8) + '#' 
             dw (07h shl 8) + '#'   

FRAME_STYLE9_CUSTOM dw (07h shl 8) + '+'
                    dw (07h shl 8) + '+'
                    dw (07h shl 8) + '+'
                    dw (07h shl 8) + '+'
                    dw (07h shl 8) + '-'
                    dw (07h shl 8) + '|'

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
