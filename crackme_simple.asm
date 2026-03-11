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

    jnz @@incorrect_password
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
; Desc: Выводит на экран сообщение о прохождении проверки пароля
; Entry:  -
; Exit:   -
; Destr:  AX
; Exp:    -
; ================================
draw_acces_granted proc
    mov ah, 09h
    mov dx, offset success_message
    int 21h

; ================================
; Desc: Выводит на экран сообщение о прохождении проверки пароля
; Entry:  -
; Exit:   -
; Destr:  AX
; Exp:    -
; ================================
draw_acces_NOT_granted proc
    mov ah, 09h
    mov dx, offset fail_message
    int 21h

; ================================
; Desc: Записывает введенный пароль на стек (храниться на стеке в обратном порядке)
; Entry:  -
; Exit:   BX — место на стеке, где начинается пароль 
; Destr:  AX
; Exp:    -
; ================================
take_password proc
    mov ah, 08h
    mov bx, sp
@@loop_start:
    int 21h
    dec sp
    mov DS:[sp], al
    cmp al, "$"
    jne @@loop_start

    push ax
    ret
; ================================
; Desc: Сравнивает 2 строки оканчивающиеся на $
; Entry:  SI, DI — аддресa начала строу
; Exit:   ZF — если выставлен, значит не равны
; Destr:  AX, DX
; Exp:    -
; ================================
cmp_strings proc 
@@cmp_loop:
    mov al, [si]
    mov dl, [di]

    cmp al, dl
    jne @@cmp_done

    cmp al, '$'
    je @@cmp_done

    inc si
    inc di
    jmp @@cmp_loop

@@cmp_done:
    ret

; ================================
; Desc: Проверяет введенный пароль
; Entry:  BX — аддрес начала пароля в обратном порядке
; Exit:   DX — совпали или нет
; Destr:  AX
; Exp:    -
; ================================
check_password proc
    mov ax, [canary_num]
    cmp ax, 0EBA1DEDAh
    jne @@return_false

    call cmp_strings
    jne @@return_false

    mov dx, 01h;
    ret 

@@return_false:
    xor dx, dx
    ret

.data

success_message  db "Happy Birthday!)$"
fail_message     db "Acces denied$"

correct_password db "Porno$"
canary_num       dw 0EBA1DEDAh

end start