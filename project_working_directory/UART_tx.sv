//`timescale 1ns/1ps
module UART_tx(clk, rst_n, TX, trmt, tx_data, tx_done);
input clk, rst_n, trmt;
input [7:0] tx_data;
output logic TX, tx_done;

typedef enum logic {IDLE, TRANSMIT} state_t;
state_t state, next_state;
logic shift; // intermidiate control signal 
// FSM OUTPUTS

logic init;
logic transmitting;
logic set_done;

// SHIFT COUNTER

logic [3:0] shift_cnt;
always_ff@(posedge clk, negedge rst_n) begin
	if (!rst_n)
		shift_cnt <= 0;
	else begin
	shift_cnt <= (init)  ? 0 : 
			 (shift) ? (shift_cnt + 1) :
			  shift_cnt;
	end
end

//BAUD COUNTER

logic [11:0] baud_cnt;
assign shift = (baud_cnt == 12'ha2c);

always_ff@(posedge clk, negedge rst_n) begin
	if (!rst_n)
		baud_cnt <= 0;
	else if (init|shift) baud_cnt <= 0;
	else if(transmitting) baud_cnt <= baud_cnt + 1;
	else baud_cnt <= baud_cnt;
end

//TX SHIFT REG
logic [8:0] tx_shft_reg;
always_ff@(posedge clk, negedge rst_n) begin
	if (!rst_n) tx_shft_reg <= '1; // active low pre-set
	else begin
		tx_shft_reg <= (init)  ? {tx_data, 1'b0} : 
			   (shift) ? {1'b1, tx_shft_reg[8:1]} :
			   tx_shft_reg;
	end
end


//TX DONE FF
always_ff@(posedge clk, negedge rst_n) begin
	if (!rst_n) tx_done <= 0;
	else if (init) tx_done <= 0;
	else if (set_done) tx_done <= 1;
	else tx_done <= tx_done;
end

assign TX = tx_shft_reg[0];

//FSM FLOP
always_ff@(posedge clk, negedge rst_n) begin
	if (!rst_n) state <= IDLE;
	else state <= next_state;
end // always_ff

//FSM TRANSITION BLOCK

always_comb begin
	next_state = state;
	init = 0;
	set_done = 0;
	transmitting = 0;
	case (state)
		IDLE :
			if(trmt) begin
				init = 1;
				transmitting = 1;
				next_state = TRANSMIT;
			end 
			else begin 
				next_state = IDLE;
			end
		TRANSMIT:
			if (shift_cnt == 4'd10) begin
				next_state = IDLE;
				set_done = 1;
			end
			else begin
				transmitting = 1;
			end
		default: next_state = IDLE;
	endcase
end // always_comb

endmodule // UART_tx
