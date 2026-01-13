//`timescale 1ns/1ps
  module PID(
	input clk,
	input rst_n,
	input moving,
	input err_vld,
	input [11:0] error,
	input [9:0] frwrd,
	output [10:0] lft_spd,
	output [10:0] rght_spd);
//P-TERM

localparam signed P_COEFF = 6'h10;
logic signed [9:0] err_sat;

assign err_sat = (~error[11] & |error[10:9])? 10'h1FF :
			  (error[11] & ~&error[10:9])? 10'h200 :
			  error[9:0]; // saturation logic
logic [9:0] err_sat_stg1;
logic err_vld_stg1;
always_ff @(posedge clk) begin
	err_sat_stg1 <= err_sat;
end
always_ff @(posedge clk) begin
	err_vld_stg1 <= err_vld;
end

			  
logic signed [13:0] P_term;
assign P_term  = err_sat_stg1 * P_COEFF; // signed multiply

//I-TERM
localparam [14:0] zero = 15'h0000; 
logic [14:0] s_ex_err_sat;
logic [14:0] adder_out;
logic overflow;
logic [14:0] sum, nxt_integrator, integrator; // mux outputs

 
assign s_ex_err_sat = {{5{err_sat_stg1[9]}} , err_sat_stg1}; // sign-extending our saturated error
assign adder_out = integrator + s_ex_err_sat; 

assign sum = (err_vld_stg1 && !overflow) ? adder_out : integrator; // mux 1
assign nxt_integrator = (moving) ? sum : zero;  // mux 2


always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n)
	integrator <= zero;
	else
	integrator <= nxt_integrator;
end

/*
 * we will overflow if the integrator and the  err_sat are both positive or both negative
 * and the result (adder_out) is of the opposite sign. 
*/

assign overflow = (~(integrator[14] ^ s_ex_err_sat[14])) & (adder_out[14] ^ integrator[14]); // use ANDs or ORs for XOR and use  err_sat for the second XOR.
logic signed [8:0] I_term;
assign I_term = integrator[14:6]; 

// D-TERM
logic [9:0] FF1, FF2, prev_err;
logic signed [7:0] D_diff_sat;
localparam signed D_COEFF = 5'h07;
logic [9:0] D_diff;
logic signed [12:0] D_term;	

// triple flopped err

always_ff@(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
	FF1 <= 0;
	FF2 <= 0;
	prev_err <= 0;  
	end // if
	else if (err_vld_stg1) begin
	FF1 <= err_sat_stg1;
	FF2 <= FF1;
	prev_err <= FF2;
	end //else
end // always_ff

assign D_diff = err_sat_stg1 - prev_err;
assign D_diff_sat = (!D_diff[9] && |D_diff[9:7]) ? 8'h7F : 
                        (D_diff[9] && ~&D_diff[9:7]) ? 8'h80 : 
                        D_diff[7:0]; // saturation logic			
assign D_term = $signed(D_diff_sat) * $signed(D_COEFF); // signed multiply

// PID_TERM
// signal declaration
logic [13:0] PID_term;
logic signed [13:0] P_term_logic;
logic signed [13:0] I_term_logic;
logic signed [13:0] D_term_logic;
logic signed [10:0] lft_spd_input;
logic [10:0] frwrd_ZERO_EX;
logic signed [10:0] rght_spd_input;
logic signed [10:0] rght_spd_mux, lft_spd_mux;

assign P_term_logic = {P_term[13], P_term[13:1]}; // sign extend
assign I_term_logic = {{5{I_term[8]}}, I_term}; // sign extend			
assign D_term_logic = {D_term[12], D_term}; // sign extend


assign PID_term = P_term_logic + I_term_logic + D_term_logic;

logic [13:0] PID_stg1; 

always_ff @ (posedge clk) begin
	PID_stg1 <= PID_term;
end


assign frwrd_ZERO_EX = {1'b0, frwrd}; // zero extend

// left and right mux select high inputs
assign lft_spd_input = frwrd_ZERO_EX + PID_stg1[13:3];
assign rght_spd_input = frwrd_ZERO_EX - PID_stg1[13:3];

// rght and lft speed muxes 
assign rght_spd_mux = (moving) ? (rght_spd_input) : 0;
assign lft_spd_mux = (moving) ? (lft_spd_input) : 0;

assign lft_spd = (!PID_stg1[13] && (lft_spd_mux[10])) ? 11'h3FF : lft_spd_mux;
assign rght_spd = (PID_stg1[13] && (rght_spd_mux[10]))? 11'h3FF : rght_spd_mux;
endmodule : PID