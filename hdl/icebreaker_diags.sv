
module top(
	input osc12m,
	output [7:0]pmod1a,
	output [7:0]pmod1b,
	output [7:0]pmod2,
	output led_red,
	output led_grn,
	input button
	);

reg [31:0]count;

always_ff @(posedge osc12m)
	count <= count + 32'h1;

assign pmod1a = count[7:0];
assign pmod1b = count[7:0];
assign pmod2 = count[7:0];

assign led_grn = count[20];
assign led_red = count[21];

endmodule
