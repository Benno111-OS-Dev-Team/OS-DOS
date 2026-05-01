TITLE   SYSINIT temporary stack segment

; Dedicated runtime stack for SYSINIT relocation/init phases.
; Keeping this in its own segment avoids growing the tightly size-limited
; SYSINIT code/data image in IO.SYS.

SYSSTKSEG SEGMENT PARA STACK 'STACK'
        PUBLIC  SYSINIT_STACK_TOP

SYSINIT_STACK           DB      3584 DUP (?)
SYSINIT_STACK_TOP       LABEL   BYTE

SYSSTKSEG ENDS
        END
