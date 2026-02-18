.model tiny
.code
org 100h

CMD_LEN    equ 80h
CMD_TAIL   equ 81h

VIDEO_SEG  equ 0B800h
COLOR      equ 07h            ; gray on black

ROW        equ 10d
COL        equ 15d
ROW_BYTES  equ 160            ; 80*2
START_DI   equ (ROW*80 + COL)*2


CH_TL      equ 0C9h           ; ╔
CH_TR      equ 0BBh           ; ╗
CH_BL      equ 0C8h           ; ╚
CH_BR      equ 0BCh           ; ╝
CH_H       equ 0CDh           ; ═
CH_V       equ 0BAh           ; ║

start:
        call init_runtime

        call read_cmd_tail_trim_spaces      ; BX=len, SI=ptr, DX=2*len
        or   bx, bx
        jz   program_exit

        call render_boxed_text              

program_exit:
        call dos_exit


; ================================
; Entry:  -                      
; Exit:   DS                     - DS=CS
;         ES                     - ES=VIDEO_SEG
; Exp:    -
; Destr:  AX                     
; ================================
init_runtime proc 
        push cs
        pop ds

        mov  ax, VIDEO_SEG
        mov  es, ax
        ret
init_runtime endp

; ================================
; Entry:  DS:PSP                 - DS указывает на PSP
; Exit:   SI                     - адрес текста
;         BX                     - длина текста
;         DX                     - длина текста в байтах
; Exp:    -
; Destr:  AX, CX                 
; ================================
read_cmd_tail_trim_spaces proc 
        xor  cx, cx
        mov  cl, byte ptr ds:[CMD_LEN]      
        mov  si, CMD_TAIL                   

        call skip_leading_spaces            

        mov  bx, cx                         
        mov  dx, bx
        add  dx, dx                         ; DX = 2*B
        ret
read_cmd_tail_trim_spaces endp

; ================================
; Entry:  DS:SI                  - текущая позиция,
;         CX                     - сколько осталось
; Exit:   SI, CX                 
; Exp:    -
; Destr:  AX                    
; ================================
skip_leading_spaces proc 
.skip:
        or   cx, cx
        jz   .done

        mov  al, byte ptr ds:[si]
        cmp  al, ' '
        jne  .done

        inc  si
        dec  cx
        jmp  .skip
.done:
        ret
skip_leading_spaces endp

; ================================
; Entry:  BX                     - длина текста
;         SI                     - адрес текста
;         DX                     - длина текста в байтах
; Exit:   -                      
; Exp:    ES=VIDEO_SEG           
; Destr:  AX, CX, DI            
; ================================
render_boxed_text proc 
        mov  di, START_DI
        sub  di, 2                          ; слева от текста

        push di
        call draw_frame_around_text          
        pop  di

        call print_text_inside_frame         
        ret
render_boxed_text endp

; ================================
; Entry:  DI                     - аддрес перед текстом
;         BX                     - длина текста
;         DX                     - длина текста в байтах
; Exit:   -                      
; Exp:    ROW_BYTES=160          - текстовый режим 80x25
; Destr:  AX, CX, DI             
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
; Entry:  DI                     - вддрес перед текстом
;         BX                     - длина текста
; Exit:   -                      
; Exp:    ES=VIDEO_SEG           
; Destr:  AX, CX, DI             
; ================================
draw_frame_top proc 
        mov  ax, di
        sub  ax, ROW_BYTES
        mov  di, ax                          ; DI = top-left

        mov  ah, COLOR
        mov  al, CH_TL
        mov  word ptr es:[di], ax

        mov  al, CH_H
        add  di, 2
        mov  cx, bx
.top_h:
        mov  word ptr es:[di], ax
        add  di, 2
        loop .top_h

        mov  al, CH_TR
        mov  word ptr es:[di], ax
        ret
draw_frame_top endp

; ================================
; Entry:  DI                     - аддрес перед текстом
;         DX                     - длина текста в битах
; Exit:   -                      
; Exp:    ES=VIDEO_SEG           
; Destr:  AX, DI                 
; ================================
draw_frame_sides proc 
        mov  ah, COLOR
        mov  al, CH_V
        mov  word ptr es:[di], ax           

        add  di, 2                           
        add  di, dx                          ; DI = START_DI + 2*len
        mov  word ptr es:[di], ax            

        ret
draw_frame_sides endp

; ================================
; Entry:  DI                     - вддрес перед текстом
;         BX                     - длина текста
; Exit:   -                      
; Exp:    ES=VIDEO_SEG           
; Destr:  AX, CX, DI             
; ================================
draw_frame_bottom proc 
        add  di, ROW_BYTES                   ; DI = bottom-left

        mov  ah, COLOR
        mov  al, CH_BL
        mov  word ptr es:[di], ax

        mov  al, CH_H
        add  di, 2
        mov  cx, bx
.bot_h:
        mov  word ptr es:[di], ax
        add  di, 2
        loop .bot_h

        mov  al, CH_BR
        mov  word ptr es:[di], ax
        ret
draw_frame_bottom endp

; ================================
; Entry:  DI                     - аддрес слева
;         SI                     - аддрес текста
;         BX                     - длина текста
; Exit:   -                      
; Exp:    ES=VIDEO_SEG           
; Destr:  AX, CX, DI, SI         
; ================================
print_text_inside_frame proc 
        add  di, 2                           ; DI = START_DI
        mov  cx, bx

.print_loop:
        mov  al, byte ptr ds:[si]
        mov  ah, COLOR
        mov  word ptr es:[di], ax

        inc  si
        add  di, 2
        loop .print_loop
        ret
print_text_inside_frame endp

; ================================
; Entry:  -                      
; Exit:   -
; Exp:    -
; Destr:  AX                     
; ================================
dos_exit proc 
        mov  ax, 4C00h
        int  21h
        ret
dos_exit endp

end start