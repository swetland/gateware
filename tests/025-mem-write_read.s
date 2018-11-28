mov r7, 0
mov r6, 0
mov r5, 0
mov r4, 0
mov r3, 0
mov r0, 0x1234
mov r1, 0x80
sw r0, [r1]
nop
nop
lw r2, [r1]
mov r7, 0x77
mov r6, 0x66
mov r5, 0x55
nop
halt

;0080 1234
;R0 1234
;R1 0080
;R2 1234
;R3 0000
;R4 0000
;R5 0055
;R6 0066
;R7 0077
