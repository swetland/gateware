mov r0, 0x11
mov r1, 0x22
mov r2, 0x33
mov r3, 0x44
add r4, r1, r2
sub r5, r3, r1
orr r6, r1, r3
slt r7, r2, r3
nop
nop
halt

;R0 0011
;R1 0022
;R2 0033
;R3 0044
;R4 0055
;R5 0022
;R6 0066
;R7 0001
