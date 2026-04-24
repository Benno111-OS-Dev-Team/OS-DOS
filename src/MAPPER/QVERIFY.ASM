;
page 80,132
;
title CP/DOS DosQVerify mapper
;
dosxxx  segment byte public 'dos'
        assume  cs:dosxxx,ds:nothing,es:nothing,ss:nothing
;
;**********************************************************************
;*
;*   MODULE:   dosqverify       Returns the value of the verify flag
;*
;*   FILE NAME: dos041.asm
;*
;*   CALLING SEQUENCE:
;*
;*       push@     word     verify setting
;*       call      dosqverify
;*
;*   MODULES CALLED:  PC-DOS Int 21h, ah=54h, get verify setting
;*
;*********************************************************************

            public   dosqverify
            .sall
            .xlist
            include  macros.inc
            .list

stk         struc
old_bp      dw       ?
return      dd       ?
verify      dd       ?     ; return data area pointer
stk         ends

dosqverify  proc    far
            EnterProc   dosqverify             ; save registers

            mov      ah,54h
            int      21h                   ; get verify flag setting

            lds      si,[bp].verify        ; setup return data area
            cbw                            ; fill word
            mov      word ptr [si],ax      ; save verify flag setting
            sub      ax,ax                 ; set good return code

exit:       Mexit                          ; pop registers
            ret      size stk - 6          ; return

dosqverify  endp

dosxxx      ends

            end
