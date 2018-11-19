	mov r0, 5
	mov r2, 0
	mov r1, 17
loop:
	add r1, r1, r1
	sub r0, r0, 1
	add r2, r2, 1
	bnz r0, loop

	mov r15, 0
	nop
	sw r0, [r15]
	sw r1, [r15]
	sw r2, [r15]
	word 0xffff

;0000 0000
;0000 0220
;0000 0005
