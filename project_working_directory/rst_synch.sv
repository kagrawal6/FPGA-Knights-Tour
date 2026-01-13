//`timescale 1ns/1ps
module rst_synch(input RST_n, input clk, output logic rst_n);
logic FF1;
always_ff @(negedge clk or negedge RST_n) begin
	if(~RST_n) begin
		 FF1 <= 0;
		 rst_n <= 0;
	end else begin
		FF1 <= 1;
		rst_n <= FF1;
	end
end
endmodule : rst_synch