//`timescale 1ns/1ps
module PB_release(
	input clk,
	input rst_n,
	input PB,
	output logic released
);

// Internal Signals
logic sig_ff1;
logic sig_ff2;
logic sig_ff3;

// Double flopping
always_ff @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		sig_ff1 <= 1;
		sig_ff2 <= 1;
		sig_ff3 <= 1;
	end else begin
		sig_ff1 <= PB;
		sig_ff2 <= sig_ff1;
		sig_ff3 <= sig_ff2;
	end
end

// Edge detection
assign released = ~sig_ff3 & sig_ff2;

endmodule