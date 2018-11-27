mov r0, 0
mov r1, 0xff
nop
sw r1, [r0, 0x00]
sw r1, [r0, 0x01]
sw r1, [r0, 0x02]
sw r1, [r0, 0x04]
sw r1, [r0, 0x08]
sw r1, [r0, 0x10]
sw r0, [r1, -1]
sw r1, [r1, -15]

;0000 00ff
;0001 00ff
;0002 00ff
;0004 00ff
;0008 00ff
;0010 00ff
;00fe 0000
;00f0 00ff
