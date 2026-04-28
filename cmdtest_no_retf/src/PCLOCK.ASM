        TITLE   CLOCK - Enable/disable clock interrupts

; "CLOCK" module for OS-DOS profile program. This implements the
;       PROFIL program on the Seattle Computer Products 8086 system

INTSEG  SEGMENT AT 0
        ORG     60H+7*4
INTVECTOR LABEL WORD
INTSEG  ENDS

CODE    SEGMENT BYTE PUBLIC

        PUBLIC  CLOCKON,CLOCKOFF,LEAVE_INT

        EXTRN   CLK_INTER:NEAR

        ASSUME  CS:CODE, DS:CODE, ES:CODE

BASE=           0F0H
STCSTAT=        BASE+5
STCDATA=        BASE+4
STCCOMND=       BASE+5
SLAVECOM=       BASE+2
MASTCOM=        BASE+0
SLAVEMASK=      BASE+3

;The following mode selects F2 as counter source (400 KHz), reload from
;load, count up once in binary with TC toggle.
MODE=           0C02H

;************************************************
;Enable clock and start generating clock interrupt.
;       Clock interval in micro seconds passed in DX
CLOCKON PROC    NEAR
        MOV     AL,4                    ;Set pointer to mode register 4
        OUT     STCCOMND,AL
        MOV     AL,MODE AND 0FFH        ;Low byte of mode
        OUT     STCDATA,AL
        MOV     AL,MODE/100H            ;High byte of mode
        OUT     STCDATA,AL
        MOV     AL,0CH                  ;Counter 4 load register
        OUT     STCCOMND,AL
        XCHG    AX,DX                   ;Count in microseconds
        XOR     DX,DX
        SHL     AX,1
        RCL     DX,1                    ;Count in DX:AX times 2
        MOV     BX,5
        DIV     BX                      ;AX=Count/2.5
        OUT     STCDATA,AL
        MOV     AL,AH
        OUT     STCDATA,AL              ;Set the load register
        MOV     AL,0E4H                 ;Clear output 4
        OUT     STCCOMND,AL

        ASSUME  DS:INTSEG

        PUSH    DS
        XOR     AX,AX
        MOV     DS,AX
;Set the clock interrupt
        MOV     INTVECTOR,OFFSET CLK_INTER
        MOV     INTVECTOR+2,CS
        POP     DS

        ASSUME  DS:CODE

        IN      AL,SLAVEMASK
        AND     AL,7FH                  ;Enable counter 4 interrupt
        OUT     SLAVEMASK,AL
        MOV     AL,68H                  ;Load and arm counter 4
        OUT     STCCOMND,AL             ;Let her rip!
        RET
CLOCKON ENDP

;************************************************
;Disable clock and clock interrupt
CLOCKOFF PROC   NEAR
        IN      AL,SLAVEMASK
        OR      AL,80H                  ;Turn off counter 4 interrupt
        OUT     SLAVEMASK,AL
        RET
CLOCKOFF ENDP


;************************************************
;This routine is jumped to from the CLK_INTER
;       routine to perform and steps to reset the interrupt
LEAVE_INT:
        PUSH    AX
        MOV     AL,0E4H                 ;Clear output 4
        OUT     STCCOMND,AL
        MOV     AL,20H                  ;End-of-interrupt command
        OUT     SLAVECOM,AL
        OUT     MASTCOM,AL
        MOV     AL,68H                  ;Load and arm counter 4
        OUT     STCCOMND,AL
        POP     AX
        IRET

CODE    ENDS
        END
