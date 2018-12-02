mov r0, 0x80
mov r1, 0xff
nop
nop
sw r1, [r0, 0x00]
sw r1, [r0, 0x01]
sw r1, [r0, 0x02]
sw r1, [r0, 0x04]
sw r1, [r0, 0x08]
sw r1, [r0, 0x10]
sw r0, [r1, -1]
sw r1, [r1, -15]

nop
nop
halt

;0080 00ff
;0081 00ff
;0082 00ff
;0084 00ff
;0088 00ff
;0090 00ff
;00fe 0080
;00f0 00ff
