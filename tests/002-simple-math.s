	mov r0, 0
	add r1, r0, 1
	add r2, r0, 2
	add r3, r1, 1
	add r4, r3, 1

	mov r15, 0
	nop

	sw r0, [r15]
	sw r1, [r15]
	sw r2, [r15]
	sw r3, [r15]
	sw r4, [r15]
	word 0xffff

;0000 0000
;0000 0001
;0000 0002
;0000 0002
;0000 0003
