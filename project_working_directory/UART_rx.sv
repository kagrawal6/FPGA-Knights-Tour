//`timescale 1ns/1ps
module UART_rx(clk,  rst_n, RX, clr_rdy, rx_data, rdy);
input clk, rst_n, RX;
input clr_rdy;
output [7:0] rx_data;
output logic rdy;

typedef enum logic {IDLE, RECEIVE} state_t;
state_t state, next_state;
//intermidiate control signals
logic shift;

//FSM OUTPUTS
logic start, receiving, set_rdy;

//RX SYNCHRONIZER FLOP(s)
logic FF1,FF2, RX_synch;

// need to double flop as RX is asynch and we can't be sure about meta-stability
always_ff@(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		FF1 <= '1;
		FF2 <= '1;
		RX_synch <= FF2;
	end
	else begin
		FF1 <= RX;
		FF2 <= FF1;
		RX_synch <= FF2;
	end
end //always_ff
logic edge_detect;

assign edge_detect = (!FF2) && (RX_synch);

//RX SHIFT REG
logic [8:0] rx_shft_reg;

always_ff@(posedge clk, negedge rst_n) begin
	if (!rst_n) 
		rx_shft_reg <= 0;
	else begin
	rx_shft_reg <= (shift) ? {RX_synch, rx_shft_reg[8:1]} :
			   rx_shft_reg;
	end
end // always_ff

assign rx_data = rx_shft_reg[7:0];

//BAUD COUNTER
logic [11:0] baud_cnt;
assign shift = (baud_cnt == 0);

always_ff@(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		baud_cnt <= 0;
	end
	else if (start|shift) begin
		baud_cnt <= (start) ? (12'd1302) :
					(shift) ? (12'd2604) : 
					0; 
		// will never init to zero as we will only take this statement if start or
		// shift is high
	end
	else if(receiving) 
		baud_cnt <= baud_cnt - 1;
	else 
		baud_cnt <= baud_cnt;
end // always_ff
	
// SHIFT COUNTER
logic [3:0] shift_cnt;

always_ff@(posedge clk, negedge rst_n) begin
	if (!rst_n)
		shift_cnt <= 0;
	else begin
	shift_cnt <= (start)  ? 0 : 
			 	 (shift) ? (shift_cnt + 1) :
			  	 shift_cnt;
	end
end //always_ff

// RX READY FF
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) 
		rdy <= 0;
	else if (clr_rdy) 
		rdy <= 0;
	else if (start) 
		rdy <= 0;
	else if (set_rdy) 
		rdy <= 1;
end // always_ff

//FSM 
always_ff@(posedge clk, negedge rst_n) begin
	if (!rst_n) 
		state <= IDLE;
	else 
		state <= next_state;
end // always_ff

always_comb begin
	next_state = state;
	set_rdy = 0;
	start = 0;
	receiving = 0;
		case(state) 
			default: //IDLE STATE	
				if (edge_detect) begin
					start = 1;
					receiving = 1;
					next_state = RECEIVE;
				end 
			RECEIVE:
				if (shift_cnt == 4'hA) begin
					next_state = IDLE;
					set_rdy = 1;
				end 
				else begin
					next_state = RECEIVE;
					receiving = 1;
				end
			
		endcase // case(state)
end // always_comb



endmodule




















