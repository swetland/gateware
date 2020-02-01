show aa
show bb
wait .25000
show cc
addr 10
wri 1234
addr 20
wri aa55
addr 10
rdc 1234
addr 20
rdc aa55

auto+
addr 0
wrp .15
show 42

p1rst
addr 0
rdp .15
show 43

show e0
p1rst
addr 0
show e1
rdf .15
show e2
wait .30
verify .15
show e3

show ff
