// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module xorshift32 #(
        parameter INITVAL = 32'hebd5a728
        ) (
        input wire clk,
        input wire next,
	input wire reset,
        output reg [31:0]data = INITVAL
);

// $ echo -n xorshiftrulz | sha256sum | cut -c 1-8
// ebd5a728

wire [31:0] nxt1 = data ^ { data[18:0], 13'd0  };
wire [31:0] nxt2 = nxt1 ^ { 17'd0, nxt1[31:17] };
wire [31:0] nxt3 = nxt2 ^ { nxt2[26:0], 5'd0   };

always_ff @(posedge clk)
	if (reset)
		data <= INITVAL;
	else if (next)
        	data <= nxt3;

endmodule

