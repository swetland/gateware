	mov r0, 0
	mov r1, 1
	mov r2, 0x1234
	mov r3, -1
	mov r4, -76

	mov r15, 0
	nop		; BUG should not be required
	sw r0, [r15]
	sw r1, [r15]
	sw r2, [r15]
	sw r3, [r15]
	sw r4, [r15]
	word 0xffff

;0000 0000
;0000 0001
;0000 1234
;0000 ffff
;0000 ffb4
