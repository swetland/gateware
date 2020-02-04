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

#trigger
auto+
addr 80 
wrp 100
show 42

p1rst
addr 80
rdp 100
show 43

show e0
p1rst

#trigger
addr f0
wri 8888

addr 80 
show e1
rdf 100
show e2
wait .30
verify 100
show e3

show ff

show 00
show 00
#dump .250

p1rst
addr 80 
show bb
rdb .15
wait .30
verify .15
show b0 

addr 1000
p0rst
#wrp ffff

addr 1000
p1rst
#rdp ffff
show a7
