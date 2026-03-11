.model tiny
.code
org 100h
LOCALS @@

VIDEO_SEG  equ 0B800h
ROW        equ 10d
COL        equ 15d
ROW_BYTES  equ 160            ; 80*2
START_DI   equ (ROW*80 + COL)*2

start:
    call init_runtime
    call take_password
    call check_password
    test dx, dx

    jz  @@incorrect_password
    call draw_acces_granted
    jmp @@program_exit

@@incorrect_password:
    call draw_acces_NOT_granted

@@program_exit:
    call dos_exit

; ================================
; Desc: Инициализирует DS и ES для работы с кодом и видеопамятью.
; Entry:  -
; Exit:   DS - DS=CS
;         ES - ES=VIDEO_SEG
; Destr:  AX
; Exp:    -
; ================================
init_runtime proc
        push cs
        pop  ds
        mov  ax, VIDEO_SEG
        mov  es, ax
        ret
init_runtime endp

; ================================
; Desc: Завершает программу через DOS (int 21h, AH=4Ch).
; Entry:  -
; Exit:   -
; Destr:  AX
; Exp:    -
; ================================
dos_exit proc
        mov  ax, 4C00h
        int  21h
        ret
dos_exit endp
    
; ================================
; Desc: Выводит на экран сообщение о прохождении проверки пароля.
; Entry:  -
; Exit:   -
; Destr:  AX
; Exp:    -
; ================================
draw_acces_granted proc
    mov ah, 09h
    mov dx, offset success_message
    int 21h
    ret
draw_acces_granted endp

; ================================
; Desc: Выводит на экран сообщение о непрохождении проверки пароля.
; Entry:  -
; Exit:   -
; Destr:  AX
; Exp:    -
; ================================
draw_acces_NOT_granted proc
    mov ah, 09h
    mov dx, offset fail_message
    int 21h
    ret
draw_acces_NOT_granted endp

; ================================
; Desc: Считывает пароль до Enter и сохраняет его на стеке.
;       После Enter добавляет завершающий символ '$'.
; Entry:  -
; Exit:   BX - адрес первого символа введенного пароля в стеке
;              (или адрес '$' при пустом вводе).
; Destr:  AX, BP
; Exp:    -
; ================================
take_password proc
    mov bp, sp
@@loop_start:
    mov ah, 08h
    int 21h
    cmp al, 0Dh
    je  @@done

    ; '$' зарезервирован как терминатор для DOS-функции вывода 09h.
    cmp al, '$'
    je  @@loop_start

    xor ah, ah
    push ax
    jmp @@loop_start

@@done:
    mov al, '$'
    xor ah, ah
    push ax

    mov bx, bp
    sub bx, 2

    ; Кладем копию адреса возврата наверх стека, чтобы RET вернулся корректно.
    push word ptr [bp]
    ret
take_password endp

; ================================
; Desc: Сравнивает две строки, оканчивающиеся на '$'.
; Entry:  SI - адрес первого символа введенного пароля в стеке.
;         DI - адрес начала эталонной строки в сегменте данных.
; Exit:   ZF - если установлен, строки равны.
; Destr:  AX, DX
; Exp:    -
; ================================
cmp_strings proc
@@cmp_loop:
    mov al, ss:[si]
    mov dl, [di]

    cmp al, dl
    jne @@cmp_done

    cmp dl, '$'
    je @@cmp_done

    sub si, 2
    inc di
    jmp @@cmp_loop

@@cmp_done:
    ret
cmp_strings endp

; ================================
; Desc: Проверяет введенный пароль.
; Entry:  BX - адрес первого символа введенного пароля в стеке.
; Exit:   DX - 1, если пароль совпал; 0 - иначе.
; Destr:  AX, SI, DI
; Exp:    -
; ================================
check_password proc
    mov ax, word ptr [canary_num]
    cmp ax, 0DEDAh
    jne @@return_false

    mov ax, word ptr [canary_num + 2]
    cmp ax, 0EBA1h
    jne @@return_false

    mov si, bx
    mov di, offset correct_password
    call cmp_strings
    jne @@return_false

    mov dx, 0001h
    ret

@@return_false:
    xor dx, dx
    ret
check_password endp

.data

success_message  db "Happy Birthday!)$"
fail_message     db "Access denied$"

correct_password db "Porno$"
canary_num       dd 0EBA1DEDAh

end start