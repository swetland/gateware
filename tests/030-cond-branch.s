mov r4, 0x44
mov r5, 0x55
mov r6, 0x66

mov r0, 0
mov r2, 10
mov r1, 0x80

again:
sw r0, [r1]
add r0, r0, 1
slt r3, r0, r2
bnz r3, again
bz r3, done
mov r5, 0xAA
mov r6, 0xBB
halt

done:
mov r7, 0x77
nop
halt

;0080 0000
;0080 0001
;0080 0002
;0080 0003
;0080 0004
;0080 0005
;0080 0006
;0080 0007
;0080 0008
;0080 0009
;R0 000a
;R1 0080
;R2 000a
;R3 0000
;R4 0044
;R5 0055
;R6 0066
;R7 0077
