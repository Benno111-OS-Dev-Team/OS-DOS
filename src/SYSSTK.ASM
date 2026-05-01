TITLE   SYSINIT temporary stack segment

; Dedicated runtime stack for SYSINIT relocation/init phases.
; Keeping this in its own segment avoids growing the tightly size-limited
; SYSINIT code/data image in IO.SYS.

SYSSTKSEG SEGMENT PARA PUBLIC 'SYSTEM_INIT'
        PUBLIC  SYSINIT_STACK_TOP

; Use explicit zero-init so this storage is emitted into the flat boot image.
; A '?' stack/BSS-style segment is not guaranteed to exist with our raw MZ->flat
; conversion path.
SYSINIT_STACK           DB      3520 DUP (0)
SYSINIT_STACK_TOP       LABEL   BYTE

SYSSTKSEG ENDS
        END
