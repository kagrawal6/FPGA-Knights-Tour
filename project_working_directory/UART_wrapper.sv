//`timescale 1ns/1ps
module UART_wrapper(clk, rst_n, clr_cmd_rdy, cmd_rdy, cmd, trmt, resp, tx_done, RX, TX);
	// module input and outpus
	input clk,rst_n;
	input clr_cmd_rdy;
	output logic cmd_rdy;
	output [15:0] cmd;
	input [7:0] resp;
	input trmt;
	output tx_done;
	input RX;
	output TX;
	
	
	typedef enum logic {IDLE, WORK} state_t;
	state_t state, next_state;

	logic clr_rdy;
	logic rx_ready; 
	logic [7:0] rx_data;
	
	UART iUART(clk,rst_n,RX,TX,rx_rdy,clr_rdy,rx_data,trmt,resp,tx_done); // provided UART instantiation

	// FSM FLOP
	
	always_ff@(posedge clk or negedge rst_n) begin
		if(!rst_n) state <= IDLE;
		else state <= next_state;
	end 

	logic [7:0] high_command; // high byte of command
	logic cmd_sel; // mux select signal.
	// 2:1 MUX fed into flop for high_command.
	always_ff@(posedge clk, negedge rst_n) begin
		if (!rst_n) high_command <= 0;
		else high_command <= (cmd_sel) ? rx_data : high_command; 
	end
	logic cmd_rdy_logic;
	// SR FLOP FOR CMD_RDY
	always_ff@(posedge clk or negedge rst_n) begin
		if (!rst_n) cmd_rdy <= 0;
		else if (clr_cmd_rdy) cmd_rdy <= 0;
		else if (cmd_rdy_logic) cmd_rdy <= 1;
	end

	assign cmd = {high_command, rx_data}; // cmd is a combination of the high byte and we use rx_data as storage for low_byte.

	// STATE TRANSITION LOGIC

	always_comb begin
		//DEFAULTS
		next_state = state;
		cmd_sel = 0;
		clr_rdy = 0;
		cmd_rdy_logic = 0;
		case (state)
			IDLE:
			// if we are done receiveing the high byte store it and get the low byte
				if (rx_rdy) begin   
					cmd_sel = 1;
					clr_rdy = 1;
					next_state = WORK;
				end
			WORK:
			// done receiving low byte now IDLE and set cmd_rdy.
				if (rx_rdy) begin
					cmd_rdy_logic = 1;
					clr_rdy = 1;
					next_state = IDLE;	
				end
		endcase
	end
endmodule

	
	