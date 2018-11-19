	mov r0, 0
	add r0, r0, 1
	add r0, r0, 1
	add r0, r0, 1
	add r0, r0, 1

	mov r15, 0
	nop

	sw r0, [r15]
	word 0xffff

;0000 0004
