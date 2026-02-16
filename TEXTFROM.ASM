.model tiny                              ; 
.code                                    ; 

org 100h                                 ; nececcary offset 100 via PSP

CMDLEN  equ 80h					         ; Address of len of cmd
CMDTAIL equ 81h					         ; Addres of start of cmd tail

start:	
	    mov  bx, CMDTAIL                 ;
	    mov  al, byte ptr DS:[CMDLEN]       ;
	    xor  ah, ah                      ;
	    add  bx, ax                      ;
		inc  bx							 ; skip space
	    mov  byte ptr [bx], '$'          ;

		mov ah, 9		                 ; Function 9 is output string
		mov dx, CMDTAIL			         ; Calculate msg address
		int 21h                          ; Interrupting and transferring control to DOS
		                                 ; for output string
         
		mov ax, 4c00h                    ; Exit and  final transfer of control
		int 21h                          ; 


end start