mov r0, 0
mov r1, 0x7777
add r2, r0, 0x1234
and r3, r1, 0xF1F1
sub r4, r1, 0x1111
slt r5, r1, 0x8000
sge r6, r1, 0x8000
sge r7, r1, 0x7777

nop
halt

;R0 0000
;R1 7777
;R2 1234
;R3 7171
;R4 6666
;R5 0001
;R6 0000
;R7 0001

