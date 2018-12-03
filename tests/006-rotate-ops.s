mov r0, 0x1234
shl r1, r0, 4
rol r2, r0, 4
ror r3, r0, 4
ror r4, r3, 1
rol r5, r4, 1
shl r6, r5, 4
rol r7, r6, 1
nop
nop
halt

;R0 1234
;R1 2340
;R2 2341
;R3 4123
;R4 a091
;R5 4123
;R6 1230
;R7 2460

