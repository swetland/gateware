mov r0, 0x4321
shr r1, r0, 4
shr r2, r1, 4
shr r3, r2, 4
shr r4, r0, 1
shr r5, r4, 1
shr r6, r5, 1
shr r7, r6, 1
nop
halt

;R0 4321
;R1 0432
;R2 0043
;R3 0004
;R4 2190
;R5 10c8
;R6 0864
;R7 0432

