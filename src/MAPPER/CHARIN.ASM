
;
page 80,132
;0
title CP/DOS KbdCharIn mapper
;
kbdxxx	segment byte public 'kbd'
	assume	cs:kbdxxx,ds:nothing,es:nothing,ss:nothing
;
; ************************************************************************* *
; *
; *	 MODULE:  kbdcharin
; *
; *	 FILE NAME:  charin.asm
; *
; *	 CALLING SEQUENCE:
; *
; *		push@	dword	chardata    ; buffer for data
; *		push	word	iowait	    ; Indicate if wait
; *		push	word	kbdhandle   ; Keyboard Handle
; *
; *		call	kbdcharin
; *
; *
; *	 MODULES CALLED:  BIOS int 16h
; *			  PC-DOS Int 21h, ah=2ch, get time
; *
; *************************************************************************

	public kbdcharin
	.sall
	.xlist
	include kbd.inc
	.list
	extrn	savedkbdinput:word



error_kbd_parameter equ 0002h

stk	struc
old_bp	dw	?
return	dd	?
handle	dw	?	 ; keyboard handle
iowait	dw	?	 ; indicate if wait for io
data	dd	?	 ; data buffer pointer
stk	ends


kbdcharin proc	 far

	EnterProc	KbdCharIn		; save registers
	lds	si,dword ptr [bp+10]	; set up return data area
loopx:
	mov	ax,savedkbdinput
	cmp	ah,0
	je	nosavedchar

	mov	savedkbdinput,0
	jmp	avail

nosavedchar:
	mov	ah,0bh			; Check for ^C
	int	021h

	mov	ah,06
	mov	dl,-1
	int	021h
	jnz	avail

	mov	ax,[bp+8]		; else, see if wait is desired
	cmp	ax,0			; if so,
	jz	loopx			;	  keep trying
					; else...
	mov	byte ptr ds:[si+0],0	; |  zero out char code
	mov	byte ptr ds:[si+1],0	; |  zero out scan code
	mov	byte ptr ds:[si+2],0	; |  zero out status
	jmp	short shift		; |  go to get shift status
					; end of block

avail:
	cmp	al,0
	je	loopx
	mov	byte ptr ds:[si+1],0	; |
	mov	byte ptr ds:[si+0],al	; |  move char&scan code into structure
	mov	byte ptr ds:[si+2],1	; |  1 for status
					;
shift:	mov	ah,02h			; Start of shift check block
	int	16h			; |  BIOS call to get shift state

	sub	ah,ah			; |
	mov	word ptr ds:[si+3],ax	; |  put shift status into structure

	mov	ah,2ch			; start time stamping
	int	21h				; |  get current time of day

	mov	byte ptr ds:[si+5],ch	; |  put hours into structure
	mov	byte ptr ds:[si+6],cl	; |  put minutes into structure
	mov	byte ptr ds:[si+7],dh	; |  put seconds into structure
	mov	byte ptr ds:[si+8],dl	; |  put hundreds into structure


	sub	ax,ax			; set good return code
	Mexit				; pop registers

	ret	size stk - 6		; return

kbdcharin endp

kbdxxx	ends

	end
