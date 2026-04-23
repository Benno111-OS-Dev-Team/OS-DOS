CODE	SEGMENT BYTE PUBLIC 'CODE'
	ASSUME CS:CODE,DS:CODE

	DB	13,10
	DB	"Microsoft OS-DOS (R)  LCD Display Font File",13,10
include copyrigh.inc
	DB	1Ah

CODE	ENDS
	END
