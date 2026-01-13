//`timescale 1ns/1ps
module cmd_proc (
	input clk,
	input rst_n,

	input logic [15:0] cmd,
	input cmd_rdy,
	output logic clr_cmd_rdy,
	output logic send_resp,

	output logic tour_go,

	input signed [11:0] heading,
	input heading_rdy,
	output logic strt_cal,
	input cal_done,
	output logic moving,

	input logic lftIR, rghtIR, cntrIR,

	output logic fanfare_go,

	output logic [9:0] frwrd,
    output logic signed [11:0] error
);
		
	parameter FAST_SIM = 1;

	typedef enum logic [2:0] {IDLE, CALIBRATE, TOUR, WAIT_ERROR, MOVE_FRWRD, MOVE_BCKWRD} state_t;

	typedef enum logic [3:0] {OP_CALIBRATE = 4'b0010, 
						      OP_MOVE = 4'b0100,
							  OP_MOVE_FNFARE = 4'b0101,
							  OP_TOUR = 4'b0110} opcode_t;

	state_t state, next_state;
	logic move_cmd;

	// FRWRD REGISTER

	logic inc_frwrd, dec_frwrd;
	logic frwrd_en;
	logic [9:0] frwrd_logic;

	logic max_speed;

	assign frwrd_logic = (FAST_SIM) ? ((inc_frwrd) ? (10'h020) : (-10'h040)) : 
									  ((inc_frwrd) ? (10'h003) : (-10'h006));

	assign max_speed = frwrd[9] & frwrd[8]; // max speed reached when top 2 bits are set
	logic frwrd_zero;
	assign frwrd_zero = ~(|frwrd);

	assign frwrd_en = ((~max_speed) & heading_rdy & inc_frwrd) | 
					  ((~frwrd_zero) & heading_rdy & dec_frwrd); // frwrd is enabled when a new heading is ready and we are either moving 
					  //frwrd or backwrd with a speed that is not zero or the max
					  
	logic clr_frwrd;
	// FRWRD REG
	always_ff @(posedge clk or negedge rst_n) begin : proc_frwrd
		if(!rst_n) begin
			frwrd <= 0;
		end else if (clr_frwrd) begin
			frwrd <= 0;
		end else if (frwrd_en) begin
			frwrd <= frwrd + frwrd_logic;
		end
	end

	// SQUARE COUNTER

	logic cntrIR_rising, cntrIR_FF1;
	always_ff @(posedge clk or negedge rst_n) begin : proc_cntrIR_FF1
		if(!rst_n) begin
			cntrIR_FF1 <= 0;
		end else begin
			cntrIR_FF1 <= cntrIR;
		end
	end
	// CNTR IR Rise edge detection logic
	assign cntrIR_rising = (~cntrIR_FF1) & (cntrIR);

	logic clr_square_cnt;
	assign clr_square_cnt = move_cmd;

	logic square_cnt_en;
	assign square_cnt_en = cntrIR_rising;

	logic [4:0] square_cnt;
	// SQUARE CNT REG
	always_ff @(posedge clk or negedge rst_n) begin : proc_square_cnt
		if(!rst_n) begin
			square_cnt <= 0;
		end else if (move_cmd) begin
			square_cnt <= 0;
		end else if (square_cnt_en) begin
			square_cnt <= square_cnt + 1;
		end
	end
	

	logic squares_to_move_en;
	assign squares_to_move_en = move_cmd;

	logic [3:0] squares_to_move;
	always_ff @(posedge clk or negedge rst_n) begin : proc_squares_to_move
		if(~rst_n) begin
			squares_to_move <= 0;
		end else if (move_cmd) begin
			squares_to_move <= cmd[3:0]; 
		end
	end

	logic move_done;
	assign move_done = ({squares_to_move, 1'b0} == square_cnt); // MOVE IS DONE when we count twice the amount of cntr_ir pulses as squares to move

	// PID_intf and error gemovingneration
	logic desired_heading_en;
	assign desired_heading_en = move_cmd;

	logic signed [11:0] desired_heading;
	logic signed [11:0] desired_heading_logic;

	assign desired_heading_logic = (|cmd[11:4]) ? {cmd[11:4], 4'hF} : 0;
	always_ff @(posedge clk or negedge rst_n) begin : proc_desired_heading
		if(!rst_n) begin
			desired_heading <= 0;
		end else if (move_cmd) 
			desired_heading <= desired_heading_logic;
	end


	logic [11:0] error_nudge;
	assign error_nudge  = (FAST_SIM) ? ( (lftIR)  ? (12'h1FF)   : ((rghtIR) ? (12'hE00) : 0) ) :
						  			   ( (lftIR)  ? (12'h05F)   : ((rghtIR) ? (12'hFA1) : 0) ) ; 

	assign error = heading - desired_heading + error_nudge;

	// FSM FLOP

	always_ff @(posedge clk or negedge rst_n) begin : proc_state
		if(~rst_n) begin
			state <= IDLE;
		end else begin
			state <= next_state;
		end
	end

	// STATE TRANSITION LOGIC

	opcode_t opcode;
	assign opcode = opcode_t'(cmd[15:12]);

	always_comb begin 

		next_state = state;
		moving = 0;
		strt_cal = 0;
		send_resp = 0;
		clr_cmd_rdy = 0;
		move_cmd = 0;
		inc_frwrd = 0;
		dec_frwrd = 0;
		fanfare_go = 0;
		tour_go = 0;
		clr_frwrd = 0;
		

		case(state) 

			default: begin  // IDLE STATE
				if (cmd_rdy) begin
					clr_cmd_rdy = 1;
					case (opcode)
						OP_MOVE: begin
							move_cmd = 1;
							clr_frwrd = 1;
							next_state = WAIT_ERROR;
						end
						OP_CALIBRATE: begin
							strt_cal = 1;
							next_state = CALIBRATE;
						end
						OP_TOUR: begin
							next_state = TOUR;
						end
						OP_MOVE_FNFARE: begin
							clr_frwrd = 1;
							move_cmd = 1;
							next_state = WAIT_ERROR;
						end
						default:
							next_state = IDLE; // default
					endcase
				end
			end

			CALIBRATE: begin
				if (cal_done) begin
					send_resp = 1;
					next_state = IDLE;
				end
			end

			WAIT_ERROR: begin
				moving = 1;
				if (error < $signed(12'h02C) && error > $signed(-12'h02C)) begin
					next_state = MOVE_FRWRD;
				end
			end

			MOVE_FRWRD : begin
				inc_frwrd  = 1;
				moving = 1;
				if (move_done) begin
					next_state = MOVE_BCKWRD;
				end
			end

			MOVE_BCKWRD : begin
				dec_frwrd = 1;
				moving = 1;
				clr_cmd_rdy = 1;
				if (frwrd_zero) begin
					fanfare_go = cmd[12];
					send_resp = 1;
					next_state = IDLE;
				end	
			end

			TOUR : begin
				tour_go = 1;
				next_state = IDLE;
			end

		endcase 

	end // always_comb	

endmodule // cmd_proc