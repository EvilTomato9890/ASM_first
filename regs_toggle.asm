.model tiny
.code
org 100h
LOCALS @@

VIDEO_SEG      equ 0B800h
STATUS_PORT    equ 64h
KEYBOARD_PORT  equ 60h

COLOR          equ 07h
TITLE_COLOR    equ 0Eh

ROW_BYTES      equ 160
FRAME_ROW      equ 8
FRAME_COL      equ 24
FRAME_WIDTH    equ 30
FRAME_HEIGHT   equ 8
FRAME_WIDTH_B  equ FRAME_WIDTH * 2

START_DI       equ (FRAME_ROW * 80 + FRAME_COL) * 2
TOPLEFT_DI     equ ((FRAME_ROW - 1) * 80 + (FRAME_COL - 1)) * 2

CLEAR_COLS     equ FRAME_WIDTH + 2
CLEAR_ROWS     equ FRAME_HEIGHT + 2
CLEAR_STRIDE   equ ROW_BYTES - (CLEAR_COLS * 2)

SC_N_MAKE      equ 31h
SC_N_BREAK     equ 0B1h
SC_ESC_MAKE    equ 01h

CH_TL          equ 0
CH_TR          equ 2
CH_BL          equ 4
CH_BR          equ 6
CH_H           equ 8
CH_V           equ 10

start:
        call init_runtime
        call drain_keyboard_buffer
        call clear_frame_area

main_loop:
        call read_scancode
        or   al, al
        jz   main_loop

        cmp  al, SC_ESC_MAKE
        je   program_exit

        cmp  al, SC_N_MAKE
        je   n_make

        cmp  al, SC_N_BREAK
        je   n_break

        jmp  main_loop

n_make:
        cmp  byte ptr [N_HELD], 0
        jne  main_loop

        mov  byte ptr [N_HELD], 1
        xor  byte ptr [FRAME_VISIBLE], 1

        cmp  byte ptr [FRAME_VISIBLE], 0
        je   hide_panel

        call capture_registers
        call update_register_lines
        call show_register_panel
        jmp  main_loop

hide_panel:
        call clear_frame_area
        jmp  main_loop

n_break:
        mov  byte ptr [N_HELD], 0
        jmp  main_loop

program_exit:
        call clear_frame_area
        call dos_exit

; ================================
; Desc: Set DS=CS and ES=video memory.
; Entry: -
; Exit:  DS=CS, ES=0B800h
; Destr: AX
; ================================
init_runtime proc
        push cs
        pop  ds

        mov  ax, VIDEO_SEG
        mov  es, ax
        ret
init_runtime endp

; ================================
; Desc: Flush pending keyboard bytes.
; Entry: -
; Exit:  -
; Destr: AL
; ================================
drain_keyboard_buffer proc
@@drain:
        in   al, STATUS_PORT
        test al, 01h
        jz   @@done

        in   al, KEYBOARD_PORT
        jmp  @@drain
@@done:
        ret
drain_keyboard_buffer endp

; ================================
; Desc: Non-blocking scancode read.
; Entry: -
; Exit:  AL=0 if no data, else scancode from 60h.
; Destr: AL
; ================================
read_scancode proc
        in   al, STATUS_PORT
        test al, 01h
        jz   @@none

        in   al, KEYBOARD_PORT
        ret
@@none:
        xor  al, al
        ret
read_scancode endp

; ================================
; Desc: Draw frame and print register lines.
; Entry: -
; Exit:  -
; Destr: AX, BX, CX, DX, DI, SI, BP
; ================================
show_register_panel proc
        mov  di, START_DI
        sub  di, 2

        mov  bx, FRAME_WIDTH
        mov  bp, FRAME_HEIGHT
        mov  dx, FRAME_WIDTH_B
        call draw_frame_around_text

        call print_register_lines
        ret
show_register_panel endp

; ================================
; Desc: Clear full frame area (border + inner content).
; Entry: -
; Exit:  -
; Destr: AX, CX, DI
; ================================
clear_frame_area proc
        mov  di, TOPLEFT_DI
        mov  ax, (COLOR shl 8) + ' '
        mov  cx, CLEAR_ROWS

@@row_loop:
        push cx
        mov  cx, CLEAR_COLS
@@col_loop:
        mov  word ptr es:[di], ax
        add  di, 2
        loop @@col_loop

        add  di, CLEAR_STRIDE
        pop  cx
        loop @@row_loop
        ret
clear_frame_area endp

; ================================
; Desc: Snapshot current registers.
; Entry: -
; Exit:  REG_* memory updated.
; Destr: AX
; ================================
capture_registers proc
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp

        mov  word ptr [REG_AX], ax
        mov  word ptr [REG_BX], bx
        mov  word ptr [REG_CX], cx
        mov  word ptr [REG_DX], dx
        mov  word ptr [REG_SI], si
        mov  word ptr [REG_DI], di
        mov  word ptr [REG_BP], bp

        mov  ax, sp
        add  ax, 14
        mov  word ptr [REG_SP], ax

        mov  ax, cs
        mov  word ptr [REG_CS], ax
        mov  ax, ds
        mov  word ptr [REG_DS], ax
        mov  ax, es
        mov  word ptr [REG_ES], ax
        mov  ax, ss
        mov  word ptr [REG_SS], ax

        pushf
        pop  ax
        mov  word ptr [REG_FL], ax

        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
capture_registers endp

; ================================
; Desc: Put register values into text templates.
; Entry: REG_* memory contains values.
; Exit:  LINE_* templates updated.
; Destr: AX, DI
; ================================
update_register_lines proc
        mov  ax, [REG_AX]
        mov  di, offset LINE_AX_BX + 3
        call word_to_hex4

        mov  ax, [REG_BX]
        mov  di, offset LINE_AX_BX + 12
        call word_to_hex4

        mov  ax, [REG_CX]
        mov  di, offset LINE_CX_DX + 3
        call word_to_hex4

        mov  ax, [REG_DX]
        mov  di, offset LINE_CX_DX + 12
        call word_to_hex4

        mov  ax, [REG_SI]
        mov  di, offset LINE_SI_DI + 3
        call word_to_hex4

        mov  ax, [REG_DI]
        mov  di, offset LINE_SI_DI + 12
        call word_to_hex4

        mov  ax, [REG_BP]
        mov  di, offset LINE_BP_SP + 3
        call word_to_hex4

        mov  ax, [REG_SP]
        mov  di, offset LINE_BP_SP + 12
        call word_to_hex4

        mov  ax, [REG_CS]
        mov  di, offset LINE_CS_DS + 3
        call word_to_hex4

        mov  ax, [REG_DS]
        mov  di, offset LINE_CS_DS + 12
        call word_to_hex4

        mov  ax, [REG_ES]
        mov  di, offset LINE_ES_SS + 3
        call word_to_hex4

        mov  ax, [REG_SS]
        mov  di, offset LINE_ES_SS + 12
        call word_to_hex4

        mov  ax, [REG_FL]
        mov  di, offset LINE_FLAGS + 6
        call word_to_hex4
        ret
update_register_lines endp

; ================================
; Desc: Convert AX to 4 hex chars at DS:DI.
; Entry: AX=value, DS:DI=target
; Exit:  DI advanced by 4
; Destr: AX, CX, DX
; ================================
word_to_hex4 proc
        push cx
        push dx

        mov  dx, ax
        mov  cx, 4
@@next_nibble:
        mov  ax, dx
        and  ax, 0F000h
        shr  ax, 12
        call nibble_to_ascii
        mov  byte ptr [di], al
        inc  di
        shl  dx, 4
        loop @@next_nibble

        pop  dx
        pop  cx
        ret
word_to_hex4 endp

; ================================
; Desc: Nibble in AL (0..15) to ASCII hex.
; Entry: AL=nibble
; Exit:  AL='0'..'F'
; Destr: AL
; ================================
nibble_to_ascii proc
        cmp  al, 9
        jbe  @@digit
        add  al, 7
@@digit:
        add  al, '0'
        ret
nibble_to_ascii endp

; ================================
; Desc: Print all register lines inside frame.
; Entry: ES=video, DS=CS
; Exit:  -
; Destr: AX, DI, SI
; ================================
print_register_lines proc
        mov  di, START_DI
        mov  si, offset TITLE_LINE
        mov  ah, TITLE_COLOR
        call print_string_at

        mov  di, START_DI + (ROW_BYTES * 1)
        mov  si, offset LINE_AX_BX
        mov  ah, COLOR
        call print_string_at

        mov  di, START_DI + (ROW_BYTES * 2)
        mov  si, offset LINE_CX_DX
        mov  ah, COLOR
        call print_string_at

        mov  di, START_DI + (ROW_BYTES * 3)
        mov  si, offset LINE_SI_DI
        mov  ah, COLOR
        call print_string_at

        mov  di, START_DI + (ROW_BYTES * 4)
        mov  si, offset LINE_BP_SP
        mov  ah, COLOR
        call print_string_at

        mov  di, START_DI + (ROW_BYTES * 5)
        mov  si, offset LINE_CS_DS
        mov  ah, COLOR
        call print_string_at

        mov  di, START_DI + (ROW_BYTES * 6)
        mov  si, offset LINE_ES_SS
        mov  ah, COLOR
        call print_string_at

        mov  di, START_DI + (ROW_BYTES * 7)
        mov  si, offset LINE_FLAGS
        mov  ah, COLOR
        call print_string_at
        ret
print_register_lines endp

; ================================
; Desc: Print zero-terminated string at ES:DI.
; Entry: DS:SI=string, ES:DI=screen, AH=color
; Exit:  SI at string end, DI after output
; Destr: AL
; ================================
print_string_at proc
@@loop:
        lodsb
        or   al, al
        jz   @@done
        mov  word ptr es:[di], ax
        add  di, 2
        jmp  @@loop
@@done:
        ret
print_string_at endp

; ================================
; Desc: Draw frame top/sides/bottom.
; Entry: DI=left cell before text, BX=inner width, DX=inner width in bytes, BP=inner height
; Exit:  -
; Destr: AX, CX, SI
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
; Desc: Draw top border.
; Entry: DI=left cell before text, BX=inner width
; Exit:  -
; Destr: AX, CX, DI, SI
; ================================
draw_frame_top proc
        sub  di, ROW_BYTES

        mov  si, [FRAME_CHARS]
        mov  ax, word ptr [si + CH_TL]
        mov  word ptr es:[di], ax

        mov  ax, word ptr [si + CH_H]
        add  di, 2
        mov  cx, bx
        jcxz @@no_h
@@top_h:
        mov  word ptr es:[di], ax
        add  di, 2
        loop @@top_h
@@no_h:
        mov  ax, word ptr [si + CH_TR]
        mov  word ptr es:[di], ax
        ret
draw_frame_top endp

; ================================
; Desc: Draw left and right borders.
; Entry: DI=left cell before text, DX=inner width in bytes, BP=inner height
; Exit:  -
; Destr: AX, CX, DI, SI
; ================================
draw_frame_sides proc
        mov  si, [FRAME_CHARS]
        mov  ax, word ptr [si + CH_V]

        mov  cx, bp
        jcxz @@done
@@row_loop:
        mov  word ptr es:[di], ax

        mov  si, di
        add  si, 2
        add  si, dx
        mov  word ptr es:[si], ax

        add  di, ROW_BYTES
        loop @@row_loop
@@done:
        ret
draw_frame_sides endp

; ================================
; Desc: Draw bottom border.
; Entry: DI=left cell before text, BX=inner width, BP=inner height
; Exit:  -
; Destr: AX, CX, DI, SI
; ================================
draw_frame_bottom proc
        mov  cx, bp
        jcxz @@at_bottom
@@move_down:
        add  di, ROW_BYTES
        loop @@move_down
@@at_bottom:
        mov  si, [FRAME_CHARS]
        mov  ax, word ptr [si + CH_BL]
        mov  word ptr es:[di], ax

        mov  ax, word ptr [si + CH_H]
        add  di, 2
        mov  cx, bx
        jcxz @@no_h
@@bot_h:
        mov  word ptr es:[di], ax
        add  di, 2
        loop @@bot_h
@@no_h:
        mov  ax, word ptr [si + CH_BR]
        mov  word ptr es:[di], ax
        ret
draw_frame_bottom endp

; ================================
; Desc: Exit to DOS.
; Entry: -
; Exit:  -
; Destr: AX
; ================================
dos_exit proc
        mov  ax, 4C00h
        int  21h
        ret
dos_exit endp

.data

FRAME_VISIBLE db 0
N_HELD        db 0

REG_AX dw 0
REG_BX dw 0
REG_CX dw 0
REG_DX dw 0
REG_SI dw 0
REG_DI dw 0
REG_BP dw 0
REG_SP dw 0
REG_CS dw 0
REG_DS dw 0
REG_ES dw 0
REG_SS dw 0
REG_FL dw 0

TITLE_LINE db 'REGISTERS SNAPSHOT', 0
LINE_AX_BX db 'AX=0000  BX=0000', 0
LINE_CX_DX db 'CX=0000  DX=0000', 0
LINE_SI_DI db 'SI=0000  DI=0000', 0
LINE_BP_SP db 'BP=0000  SP=0000', 0
LINE_CS_DS db 'CS=0000  DS=0000', 0
LINE_ES_SS db 'ES=0000  SS=0000', 0
LINE_FLAGS db 'FLAGS=0000', 0

FRAME_STYLE1 dw (COLOR shl 8) + 0C9h
             dw (COLOR shl 8) + 0BBh
             dw (COLOR shl 8) + 0C8h
             dw (COLOR shl 8) + 0BCh
             dw (COLOR shl 8) + 0CDh
             dw (COLOR shl 8) + 0BAh

FRAME_CHARS dw offset FRAME_STYLE1

end start
