.model tiny
.code
org 100h

; ====== Notes on abbreviations ======
; AX (Accumulator Register), BX (Base Register), CX (Count Register), DX (Data Register)
; SI (Source Index), DI (Destination Index)
; CS (Code Segment), DS (Data Segment), ES (Extra Segment), SS (Stack Segment)
; PSP (Program Segment Prefix)
; ZF (Zero Flag), CF (Carry Flag)
; ====================================

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
        call InitRuntime              ; DS=CS, ES=VIDEO_SEG

        call ReadCmdTailTrimSpaces    ; BX=len, SI=ptr, DX=2*len
        or   bx, bx
        jz   ProgramExit

        call RenderBoxedText          ; uses BX,SI,DX

ProgramExit:
        call DosExit                  ; terminate

; ============================================================================

; "
; Entry: -  (ничего)
; Exit:  DS - DS=CS (для .COM обычно уже так, но делаем явно)
;        ES - ES=VIDEO_SEG (видеопамять текстового режима)
; Exp:   -  (запуск .COM: PSP в сегменте CS)
; Destr: AX
; "
InitRuntime proc near
        call InitDS
        call InitVideoES
        ret
InitRuntime endp

; "
; Entry: CS - сегмент кода (и PSP для .COM)
; Exit:  DS - сегмент данных = CS
; Exp:   стек доступен для push/pop
; Destr: AX
; "
InitDS proc near
        push cs
        pop  ds
        ret
InitDS endp

; "
; Entry: -  (ничего)
; Exit:  ES - сегмент видеопамяти B800h
; Exp:   VIDEO_SEG = 0B800h
; Destr: AX
; "
InitVideoES proc near
        mov  ax, VIDEO_SEG
        mov  es, ax
        ret
InitVideoES endp

; ============================================================================

; "
; Entry: DS:PSP - DS указывает на PSP, где лежит хвост командной строки
; Exit:  SI - адрес начала текста (без ведущих пробелов) в PSP хвосте
;        BX - длина текста в символах
;        DX - длина текста в байтах для видеопамяти (2*BX)
; Exp:   DS = PSP сегмент (для .COM это CS)
; Destr: AX, CX
; "
ReadCmdTailTrimSpaces proc near
        xor  cx, cx
        mov  cl, byte ptr ds:[CMD_LEN]   ; длина хвоста
        mov  si, CMD_TAIL                ; начало хвоста

        call SkipLeadingSpaces           ; (SI,CX) -> после пробелов

        mov  bx, cx                      ; BX = длина текста (может быть 0)
        call MulLenBy2_ToDX              ; DX = 2*BX
        ret
ReadCmdTailTrimSpaces endp

; "
; Entry: DS:SI - указатель на хвост командной строки
;        CX    - сколько символов осталось просмотреть
; Exit:  SI - сдвинут на первый НЕ-пробел
;        CX - уменьшен на число пропущенных пробелов
; Exp:   CX >= 0, память DS:SI..SI+CX-1 доступна
; Destr: AX
; "
SkipLeadingSpaces proc near
.skip:
        or   cx, cx
        jz   .done
        mov  al, byte ptr ds:[si]
        cmp  al, ' '
        jne  .done
        inc  si
        dec  cx
        jmp  short .skip
.done:
        ret
SkipLeadingSpaces endp

; "
; Entry: BX - длина строки в символах
; Exit:  DX - 2*BX (байт в видеопамяти на строку текста)
; Exp:   BX в пределах 0..127 (для хвоста PSP)
; Destr: -
; "
MulLenBy2_ToDX proc near
        mov  dx, bx
        add  dx, dx
        ret
MulLenBy2_ToDX endp

; ============================================================================

; "
; Entry: BX - длина текста
;        SI - указатель на текст
;        DX - 2*BX
; Exit:  -  (рамка и текст нарисованы в видеопамяти)
; Exp:   ES = VIDEO_SEG
; Destr: AX, CX, DI
; "
RenderBoxedText proc near
        call GetLeftBorderDI             ; DI = START_DI-2

        ; рамка
        call DrawTopBorder               ; uses DI,BX
        call DrawSideBorders             ; uses DI,DX
        call DrawBottomBorder            ; uses DI,BX

        ; текст
        call PrintTextInsideFrame        ; uses DI_left, SI, BX
        ret
RenderBoxedText endp

; ============================================================================

; "
; Entry: -  (ничего)
; Exit:  DI - смещение левой вертикальной границы (ячейка слева от текста) на строке текста
; Exp:   START_DI корректен
; Destr: -
; "
GetLeftBorderDI proc near
        mov  di, START_DI
        sub  di, 2
        ret
GetLeftBorderDI endp

; "
; Entry: DI - DI_left (левая граница на строке текста)
; Exit:  DI - DI_top_left (левый верхний угол рамки)
; Exp:   ROW_BYTES = 160
; Destr: AX
; "
GetTopLeftDI proc near
        mov  ax, di
        sub  ax, ROW_BYTES
        mov  di, ax
        ret
GetTopLeftDI endp

; "
; Entry: DI - DI_left (левая граница на строке текста)
; Exit:  DI - DI_bottom_left (левый нижний угол рамки)
; Exp:   ROW_BYTES = 160
; Destr: AX
; "
GetBottomLeftDI proc near
        mov  ax, di
        add  ax, ROW_BYTES
        mov  di, ax
        ret
GetBottomLeftDI endp

; "
; Entry: DI - DI_left
;        DX - 2*len (в байтах)
; Exit:  DI - DI_right (правая граница рамки на строке текста)
; Exp:   DX = 2*BX
; Destr: AX
; "
GetRightBorderDI proc near
        mov  ax, di
        add  ax, 2           ; START_DI = DI_left + 2
        add  ax, dx          ; + 2*len
        mov  di, ax
        ret
GetRightBorderDI endp

; ============================================================================

; "
; Entry: DI - куда писать (смещение в видеопамяти)
;        AL - символ
; Exit:  es:[DI] - записана пара (символ, атрибут)
; Exp:   ES = VIDEO_SEG, COLOR задан
; Destr: AX
; "
PutCharColor proc near
        mov  ah, COLOR
        call PutCellAX
        ret
PutCharColor endp

; "
; Entry: ES:DI - адрес ячейки видеопамяти
;        AX    - AH=атрибут, AL=символ
; Exit:  es:[DI] = AX
; Exp:   ES = VIDEO_SEG
; Destr: -
; "
PutCellAX proc near
        mov  word ptr es:[di], ax
        ret
PutCellAX endp

; ============================================================================

; "
; Entry: DI - позиция угла
; Exit:  в DI записан символ ╔
; Exp:   ES = VIDEO_SEG
; Destr: AX
; "
PutTL proc near
        mov  al, CH_TL
        call PutCharColor
        ret
PutTL endp

; "
; Entry: DI - позиция угла
; Exit:  в DI записан символ ╗
; Exp:   ES = VIDEO_SEG
; Destr: AX
; "
PutTR proc near
        mov  al, CH_TR
        call PutCharColor
        ret
PutTR endp

; "
; Entry: DI - позиция угла
; Exit:  в DI записан символ ╚
; Exp:   ES = VIDEO_SEG
; Destr: AX
; "
PutBL proc near
        mov  al, CH_BL
        call PutCharColor
        ret
PutBL endp

; "
; Entry: DI - позиция угла
; Exit:  в DI записан символ ╝
; Exp:   ES = VIDEO_SEG
; Destr: AX
; "
PutBR proc near
        mov  al, CH_BR
        call PutCharColor
        ret
PutBR endp

; "
; Entry: DI - позиция
; Exit:  в DI записан символ ═
; Exp:   ES = VIDEO_SEG
; Destr: AX
; "
PutH proc near
        mov  al, CH_H
        call PutCharColor
        ret
PutH endp

; "
; Entry: DI - позиция
; Exit:  в DI записан символ ║
; Exp:   ES = VIDEO_SEG
; Destr: AX
; "
PutV proc near
        mov  al, CH_V
        call PutCharColor
        ret
PutV endp

; ============================================================================

; "
; Entry: DI - стартовая позиция (первая ячейка линии)
;        CX - сколько символов рисовать
; Exit:  DI - позиция после последнего нарисованного символа (DI += 2*CX)
; Exp:   ES = VIDEO_SEG
; Destr: AX, CX
; "
DrawHLine proc near
.hloop:
        or   cx, cx
        jz   .done
        call PutH
        add  di, 2
        dec  cx
        jmp  short .hloop
.done:
        ret
DrawHLine endp

; ============================================================================

; "
; Entry: DI - DI_left (левая граница на строке текста)
;        BX - длина текста
; Exit:  верхняя рамка нарисована
; Exp:   ES = VIDEO_SEG, ROW_BYTES корректен
; Destr: AX, CX, DI
; "
DrawTopBorder proc near
        push di                      ; сохраним DI_left на выход (не обяз., но удобно)
        call GetTopLeftDI            ; DI = top-left corner

        call PutTL

        add  di, 2
        mov  cx, bx
        call DrawHLine               ; рисуем BX раз '═'

        call PutTR

        pop  di                      ; восстановим DI_left
        ret
DrawTopBorder endp

; "
; Entry: DI - DI_left (левая граница на строке текста)
;        BX - длина текста
; Exit:  нижняя рамка нарисована
; Exp:   ES = VIDEO_SEG, ROW_BYTES корректен
; Destr: AX, CX, DI
; "
DrawBottomBorder proc near
        push di
        call GetBottomLeftDI         ; DI = bottom-left corner

        call PutBL

        add  di, 2
        mov  cx, bx
        call DrawHLine

        call PutBR

        pop  di
        ret
DrawBottomBorder endp

; "
; Entry: DI - DI_left (левая граница на строке текста)
;        DX - 2*len (байты)
; Exit:  боковые границы на строке текста нарисованы
; Exp:   ES = VIDEO_SEG
; Destr: AX, DI
; "
DrawSideBorders proc near
        push di

        ; left side at DI_left
        call PutV

        ; right side at START_DI + DX  == (DI_left + 2) + DX
        pop  di
        push di
        call GetRightBorderDI
        call PutV

        pop  di
        ret
DrawSideBorders endp

; ============================================================================

; "
; Entry: DI - DI_left (левая граница на строке текста)
;        SI - указатель на текст (в PSP хвосте)
;        BX - длина текста
; Exit:  текст выведен внутрь рамки
; Exp:   ES = VIDEO_SEG, DI_left = START_DI-2
; Destr: AX, CX, DI, SI
; "
PrintTextInsideFrame proc near
        add  di, 2               ; DI = START_DI
        mov  cx, bx
.ploop:
        or   cx, cx
        jz   .done
        mov  al, byte ptr ds:[si]
        call PutCharColor
        inc  si
        add  di, 2
        dec  cx
        jmp  short .ploop
.done:
        sub  di, 2               ; вернуть DI к позиции "последний символ" не нужно, но оставим DI близко к исходному
        ret
PrintTextInsideFrame endp

; ============================================================================

; "
; Entry: -  (ничего)
; Exit:  управление возвращено DOS
; Exp:   INT 21h доступен
; Destr: AX
; "
DosExit proc near
        mov  ax, 4C00h
        int  21h
        ret                       ; фактически не вернётся
DosExit endp

end start