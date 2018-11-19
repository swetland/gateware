	mov r15, 0x100
	mov r14, 0x108
	mov r0, 0xabcd

loop:
	slt r1, r15, r14
	bnz r1, done
	sw r0, [r15]
	add r15, r15, 1
	nop
	b loop

done:
	word 0xffff


;0100 abcd
;0101 abcd
;0102 abcd
;0103 abcd
;0104 abcd
;0105 abcd
;0106 abcd
;0107 abcd
;0100 0000
