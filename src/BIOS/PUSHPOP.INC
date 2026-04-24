?stackdepth = 0

SaveReg MACRO	reglist 		;; push those registers
IRP reg,<reglist>
	?stackdepth = ?stackdepth + 1
	PUSH	reg
ENDM
ENDM
.xcref	SaveReg

RestoreReg  MACRO   reglist		;; pop those registers
IRP reg,<reglist>
	?stackdepth = ?stackdepth - 1
	POP	reg
ENDM
ENDM
.xcref	RestoreReg
