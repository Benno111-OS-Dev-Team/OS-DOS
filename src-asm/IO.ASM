; IO.ASM -- Standard I/O routines for OS-DOS
; Included by STDIO.ASM within the DOSGROUP segment context.
;
; STDIO.ASM already includes STDSW.ASM (defines ESCCH, CANCEL, etc.)
; and DOSSEG.ASM (declares CODE/DATA/CONSTANTS/LAST and DOSGROUP).
; This file includes DOSSYM.ASM + DEVSYM.ASM for structures/constants.
;
; Symbols defined here:
;   Data  : DEVIOBUF, ESCCHAR, INSMODE
;   Code  : GET_IO_FCB, OUT_ROUTINE, TAB
;           $STD_CON_INPUT, $STD_CON_OUTPUT, $STD_AUX_INPUT
;           $STD_AUX_OUTPUT, $STD_PRINTER_OUTPUT
;           $STD_CON_STRING_OUTPUT, $STD_CON_INPUT_NO_ECHO
;           $STD_CON_INPUT_STATUS, $STD_CON_INPUT_FLUSH
;           (STRIN.ASM contributes: $STD_CON_STRING_INPUT, GETCH,
;            CRLF, KILNEW, BACKSP, TWOESC, COPYLIN, COPYSTR, COPYONE,
;            SKIPONE, SKIPSTR, REEDIT, EXITINS, ENTERINS, CTRLZ)
;           OEMFunctionKey

SUBTTL  IO - standard device I/O for OSDOS
PAGE

; Bring in all macro/structure/constant definitions.
; These generate no segment data -- safe to include here at top level.
.xlist
.xcref
INCLUDE DOSSYM.ASM
INCLUDE DEVSYM.ASM
.cref
.list

;-------------------------------------------------------------------------
; Data items owned by this module (in the DATA segment = DOSGROUP)
;-------------------------------------------------------------------------
DATA    SEGMENT

        I_AM    DEVIOBUF,4          ; 4-byte device I/O transfer buffer

        PUBLIC  ESCCHAR
ESCCHAR DB      ESCCH               ; escape lead-byte (from STDSW.ASM EQU)

        I_AM    INSMODE,BYTE        ; non-zero = line-insert mode active

DATA    ENDS

;-------------------------------------------------------------------------
; Code
;-------------------------------------------------------------------------
CODE    SEGMENT
ASSUME  SS:DOSGROUP,CS:DOSGROUP

; ---- Data items from other modules ----
        I_NEED  BCON,DWORD          ; CON device header far pointer
        I_NEED  COUTSAV,DWORD       ; current stdout device far pointer
        I_NEED  CINSAV,DWORD        ; current stdin device far pointer
        I_NEED  CARPOS,BYTE         ; cursor column (0-based)
        I_NEED  STARTPOS,BYTE       ; cursor column at line start
        I_NEED  INBUF,128           ; keyboard line-input buffer
        I_NEED  PFLAG,BYTE          ; printer-echo flag
        I_NEED  DSKSTCALL,BYTE      ; DEVRDND/DEVRD request header
        I_NEED  DSKSTCOM,BYTE       ; command byte at DSKSTCALL+2
        I_NEED  DSKSTST,WORD        ; status word at DSKSTCALL+3
        I_NEED  DSKSTCNT,WORD       ; count word in DSKSTCALL
        I_NEED  DSKCHRET,BYTE       ; char returned by DEVRDND
        I_NEED  IOCALL,BYTE         ; general device-call header (SRHEAD)
        I_NEED  IOMED,BYTE          ; media byte  (IOCALL+5)
        I_NEED  IOXAD,DWORD         ; transfer address (IOCALL+6)
        I_NEED  IOSCNT,WORD         ; byte count  (IOCALL+10)
        I_NEED  sft_addr,DWORD      ; system file table chain head
        I_NEED  CurrentPDB,WORD     ; current process PDB segment

        EXTRN   IOFUNC:NEAR
        EXTRN   DEVIOCALL:NEAR,DEVIOCALL2:NEAR
        EXTRN   get_sf_from_jfn:NEAR
        EXTRN   save_world:NEAR,restore_world:NEAR

;=========================================================================
SUBTTL  GET_IO_FCB - map JFN to sf_entry pointer
;=========================================================================
; Input:   BX = JFN  (0=stdin  1=stdout  2=stderr  3=aux  4=prn)
; Output:  NC -> ES:DI = pointer to sf_entry  (CF propagated from get_sf_from_jfn)
;          C  -> invalid JFN
;
        procedure   GET_IO_FCB,NEAR
        ASSUME  DS:DOSGROUP,ES:NOTHING
        INVOKE  get_sf_from_jfn         ; ES:DI -> sf_entry, CF on error
        return
GET_IO_FCB  ENDP

;=========================================================================
SUBTTL  OUT_ROUTINE - output one character to the current stdout device
;=========================================================================
; Input:   AL = character to output
; Regs:    all preserved; CARPOS updated
;
        procedure   OUT_ROUTINE,NEAR
        ASSUME  DS:DOSGROUP,ES:NOTHING
        PUSH    AX
        PUSH    BX
        PUSH    DS
        PUSH    SI

        MOV     [DEVIOBUF],AL
        MOV     WORD PTR [IOXAD],OFFSET DOSGROUP:DEVIOBUF
        MOV     WORD PTR [IOXAD+2],SS
        MOV     WORD PTR [IOSCNT],1
        XOR     BX,BX
        MOV     [IOCALL.REQSTAT],BX
        MOV     BYTE PTR [IOMED],BL
        MOV     BYTE PTR [IOCALL.REQLEN],DRDWRHL
        MOV     BYTE PTR [IOCALL.REQFUNC],DEVWRT
        MOV     BX,OFFSET DOSGROUP:IOCALL
        LDS     SI,[COUTSAV]
        ASSUME  DS:NOTHING
        INVOKE  DEVIOCALL2

        POP     SI
        POP     DS
        ASSUME  DS:DOSGROUP
        POP     BX
        POP     AX

        CMP     AL,c_CR
        JNZ     OUT_NOT_CR
        MOV     BYTE PTR [CARPOS],0
        return
OUT_NOT_CR:
        CMP     AL,c_LF
        JZ      OUT_DONE
        CMP     AL,c_BS
        JNZ     OUT_NOT_BS
        CMP     BYTE PTR [CARPOS],0
        JZ      OUT_DONE
        DEC     BYTE PTR [CARPOS]
        return
OUT_NOT_BS:
        CMP     AL,c_HT
        JNZ     OUT_NOT_TAB
        MOV     AL,BYTE PTR [CARPOS]
        ADD     AL,8
        AND     AL,0F8H
        MOV     BYTE PTR [CARPOS],AL
        return
OUT_NOT_TAB:
        CMP     AL,' '
        JAE     OUT_PRINTABLE
        ; control char: displayed as ^X, occupies 2 columns
        INC     BYTE PTR [CARPOS]
        INC     BYTE PTR [CARPOS]
        return
OUT_PRINTABLE:
        INC     BYTE PTR [CARPOS]
OUT_DONE:
        return
OUT_ROUTINE ENDP

;=========================================================================
SUBTTL  TAB - output spaces to advance cursor to column given in AL
;=========================================================================
; Input:   AL = number of spaces to emit
; Regs:    all preserved
;
        procedure   TAB,NEAR
        ASSUME  DS:DOSGROUP,ES:NOTHING
        OR      AL,AL
        JZ      TAB_DONE
        PUSH    CX
        XOR     CH,CH
        MOV     CL,AL
TAB_LOOP:
        MOV     AL,' '
        INVOKE  OUT_ROUTINE
        LOOP    TAB_LOOP
        POP     CX
TAB_DONE:
        return
TAB ENDP

;=========================================================================
SUBTTL  $STD_CON_INPUT_NO_ECHO - read char from stdin, no echo (fn 8)
;=========================================================================
; Output:  AL = character read
;
        procedure   $STD_CON_INPUT_NO_ECHO,NEAR
        ASSUME  DS:DOSGROUP,ES:NOTHING
        PUSH    BX
        PUSH    DS
        PUSH    SI

        MOV     WORD PTR [IOXAD],OFFSET DOSGROUP:DEVIOBUF
        MOV     WORD PTR [IOXAD+2],SS
        MOV     WORD PTR [IOSCNT],1
        XOR     BX,BX
        MOV     [IOCALL.REQSTAT],BX
        MOV     BYTE PTR [IOMED],BL
        MOV     BYTE PTR [IOCALL.REQLEN],DRDWRHL
        MOV     BYTE PTR [IOCALL.REQFUNC],DEVRD
        MOV     BX,OFFSET DOSGROUP:IOCALL
        LDS     SI,[CINSAV]
        ASSUME  DS:NOTHING
        INVOKE  DEVIOCALL2

        POP     SI
        POP     DS
        ASSUME  DS:DOSGROUP
        POP     BX
        MOV     AL,BYTE PTR [DEVIOBUF]
        return
$STD_CON_INPUT_NO_ECHO  ENDP

;=========================================================================
SUBTTL  $STD_CON_INPUT - read char with echo (fn 1)
;=========================================================================
; Output:  AL = character
;
        procedure   $STD_CON_INPUT,NEAR
        ASSUME  DS:DOSGROUP,ES:NOTHING
        INVOKE  $STD_CON_INPUT_NO_ECHO
        INVOKE  OUT_ROUTINE
        return
$STD_CON_INPUT  ENDP

;=========================================================================
SUBTTL  $STD_CON_OUTPUT - write char in DL to stdout (fn 2)
;=========================================================================
        procedure   $STD_CON_OUTPUT,NEAR
        ASSUME  DS:DOSGROUP,ES:NOTHING
        MOV     AL,DL
        INVOKE  OUT_ROUTINE
        return
$STD_CON_OUTPUT ENDP

;=========================================================================
SUBTTL  $STD_AUX_INPUT - read from AUX device via SFT (fn 3)
;=========================================================================
; Output:  AL = character; 0 returned if JFN unavailable
;
        procedure   $STD_AUX_INPUT,NEAR
        ASSUME  DS:DOSGROUP,ES:NOTHING
        PUSH    BX
        MOV     BX,3                    ; JFN 3 = AUX
        INVOKE  GET_IO_FCB
        JC      AUX_IN_DONE
        XOR     AH,AH                   ; IOFUNC fn 0 = input
        INVOKE  IOFUNC
AUX_IN_DONE:
        POP     BX
        return
$STD_AUX_INPUT  ENDP

;=========================================================================
SUBTTL  $STD_AUX_OUTPUT - write DL to AUX device (fn 4)
;=========================================================================
        procedure   $STD_AUX_OUTPUT,NEAR
        ASSUME  DS:DOSGROUP,ES:NOTHING
        PUSH    AX
        PUSH    BX
        MOV     AL,DL
        MOV     BX,3                    ; JFN 3 = AUX
        INVOKE  GET_IO_FCB
        JC      AUX_OUT_DONE
        MOV     AH,2                    ; IOFUNC fn 2 = output
        INVOKE  IOFUNC
AUX_OUT_DONE:
        POP     BX
        POP     AX
        return
$STD_AUX_OUTPUT ENDP

;=========================================================================
SUBTTL  $STD_PRINTER_OUTPUT - write DL to PRN device (fn 5)
;=========================================================================
        procedure   $STD_PRINTER_OUTPUT,NEAR
        ASSUME  DS:DOSGROUP,ES:NOTHING
        PUSH    AX
        PUSH    BX
        MOV     AL,DL
        MOV     BX,4                    ; JFN 4 = PRN
        INVOKE  GET_IO_FCB
        JC      PRN_OUT_DONE
        MOV     AH,2                    ; IOFUNC fn 2 = output
        INVOKE  IOFUNC
PRN_OUT_DONE:
        POP     BX
        POP     AX
        return
$STD_PRINTER_OUTPUT ENDP

;=========================================================================
SUBTTL  $STD_CON_STRING_OUTPUT - write '$'-terminated string (fn 9)
;=========================================================================
; Input:   DS:DX = far pointer to string (DS is caller's segment)
;
        procedure   $STD_CON_STRING_OUTPUT,NEAR
        ASSUME  DS:NOTHING,ES:NOTHING
        PUSH    SI
        MOV     SI,DX
STR_OUT_LOOP:
        MOV     AL,[SI]
        INC     SI
        CMP     AL,'$'
        JZ      STR_OUT_DONE
        INVOKE  OUT_ROUTINE
        JMP     SHORT STR_OUT_LOOP
STR_OUT_DONE:
        POP     SI
        return
$STD_CON_STRING_OUTPUT  ENDP

;=========================================================================
SUBTTL  $STD_CON_INPUT_STATUS - keyboard status check (fn 11)
;=========================================================================
; Output:  AL = 0 if no char waiting, 0FFH if char available
;
        procedure   $STD_CON_INPUT_STATUS,NEAR
        ASSUME  DS:DOSGROUP,ES:NOTHING
        PUSH    BX
        PUSH    DS
        PUSH    SI

        MOV     BYTE PTR [DSKSTCALL],DRDNDHL
        MOV     BYTE PTR [DSKSTCOM],DEVRDND
        XOR     BX,BX
        MOV     [DSKSTST],BX
        MOV     BX,OFFSET DOSGROUP:DSKSTCALL
        LDS     SI,[CINSAV]
        ASSUME  DS:NOTHING
        INVOKE  DEVIOCALL2

        POP     SI
        POP     DS
        ASSUME  DS:DOSGROUP
        POP     BX

        TEST    WORD PTR [DSKSTST],STBUI
        JNZ     CON_STS_NONE
        MOV     AL,0FFH
        return
CON_STS_NONE:
        XOR     AL,AL
        return
$STD_CON_INPUT_STATUS   ENDP

;=========================================================================
SUBTTL  $STD_CON_INPUT_FLUSH - flush keyboard buffer (fn 12)
;=========================================================================
        procedure   $STD_CON_INPUT_FLUSH,NEAR
        ASSUME  DS:DOSGROUP,ES:NOTHING
        PUSH    BX
        PUSH    DS
        PUSH    SI

        MOV     BYTE PTR [DSKSTCALL],DFLSHL
        MOV     BYTE PTR [DSKSTCOM],DEVIFL
        XOR     BX,BX
        MOV     [DSKSTST],BX
        MOV     BX,OFFSET DOSGROUP:DSKSTCALL
        LDS     SI,[CINSAV]
        ASSUME  DS:NOTHING
        INVOKE  DEVIOCALL2

        POP     SI
        POP     DS
        ASSUME  DS:DOSGROUP
        POP     BX
        return
$STD_CON_INPUT_FLUSH    ENDP

;=========================================================================
SUBTTL  STRIN - keyboard line-edit/template engine
;=========================================================================
; STRIN.ASM defines: $STD_CON_STRING_INPUT (fn 10), GETCH, CRLF, KILNEW,
;   BACKSP, TWOESC, COPYLIN, COPYSTR, COPYONE, SKIPONE, SKIPSTR, REEDIT,
;   EXITINS, ENTERINS, CTRLZ.
; Its EXTRN for OUT_ROUTINE, TAB, $STD_CON_INPUT_NO_ECHO is stripped by
; the workflow patch (those symbols are already defined above in this file).
;
        INCLUDE STRIN.ASM

;=========================================================================
SUBTTL  OEMFunctionKey - handle extended (two-byte) scan-code sequences
;=========================================================================
; STRIN.ASM jumps here when the escape lead-byte is received.
; We consume the second (scan-code) byte, then resume normal input.
;
OEMFunctionKey  LABEL   NEAR
        INVOKE  $STD_CON_INPUT_NO_ECHO  ; discard scan-code byte
        transfer    GETCH               ; resume line-input loop

CODE    ENDS

END
