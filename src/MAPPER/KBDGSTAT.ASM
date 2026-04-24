;0
page 80,132
;
title CP/DOS KbdGetStatus
;
	.sall
	.xlist
	include kbd.inc
	.list

kbddata segment word public 'kbddata'

		public	KbdBitMask
KbdBitMask	dw	CookedModeOn or EchoOn

		public	KbdTurnAroundCharacter
KbdTurnAroundCharacter	dw	0dh

		public	KbdInterimCharFlags
KbdInterimCharFlags	dw	0

kbddata ends

kbdxxx	segment byte public 'kbd'
	assume	cs:kbdxxx,ds:nothing,es:nothing,ss:nothing
;
; ************************************************************************* *
; *
; *	 MODULE:  kbdGetStatus
; *
; *	 CALLING SEQUENCE:
; *
; *
; *************************************************************************

	public kbdgetstatus

stk	struc
old_bp	dw	?
return	dd	?
handle	dw	?      ; kbd handle
data	dd	?      ; data area pointer
stk	ends

kbdgetstatus	proc	far

	EnterProc	KbdGetStatus		; push registers

	les	di,[bp].data		; setup area where status is
					; returned
	mov	ax,seg kbddata
	mov	ds,ax
	assume	ds:kbddata

	mov	ax,KbdBitMask			 ; save kbd bit mask in
	mov	es:[di].Bit_Mask,ax		 ; return data area

	mov	ax,KbdTurnAroundCharacter	 ; save turn around character
	mov	es:[di].Turn_Around_Char,ax

	mov	ax,KbdInterimCharFlags		 ; save interim character flag
	mov	es:[di].Interim_Char_Flags,ax

	mov	ah,2
	int	16h				 ; get kbd shift status

	xor	ah,ah
	mov	es:[di].Status_Shift_State,ax	 ; save it in return data
						 ; area
	Mexit					 ; restore registers

	ret	size stk - 6			 ; return

kbdgetstatus	endp
kbdxxx	ends
	end
