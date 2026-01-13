//`timescale 1ns/1ps
module PWM11(
	input clk,
	input rst_n,
	input [10:0]duty,
	output reg PWM_sig,
	output reg PWM_sig_n
);
logic [10:0] cnt;
logic d;

// Counter Logic
always_ff @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		cnt <= 11'h000;
	else
		cnt <= cnt + 11'h001;
	end

// Count comparison
assign d = (cnt < duty) ? 1'b1 : 1'b0;

// PWM output
always_ff @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		PWM_sig <= 1'b0;
	else
		PWM_sig <= d;	
	end
	
assign PWM_sig_n = ~PWM_sig;

endmodule