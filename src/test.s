	mov r0, #0
	mov r1, #1
	mov r1, #7
	mov r2, #2
	mov r3, #3
	add r3, r3, #1
	mov r3, #0xFEED
	add r2, r2, #1
	add r2, r2, #1
	add r2, r2, #1
	add r2, r2, #1

	mov r0, #0xE000
	mov r1, #0x1234
	mov r2, #5
	bl fill

	mov r0, #0xE000
	mov r1, #0x4321;
	mov r2, #5
	bl fill

	mov r0, #0xE000
	lw r3, [r0]
	mov r2, r3
	mov r0, #0xDEAD
	b .

fill: // r0=addr r1=value r2=count
	sw r1, [r0]
	add r0, r0, #1
	sub r2, r2, #1
	bnz r2, fill
	b lr
