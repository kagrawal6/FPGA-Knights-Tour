//`timescale 1ns/1ps
module TourCmd(
  input clk,
  input rst_n,                // 50MHz clock and asynchronous active low reset
  input start_tour,           // from done signal from TourLogic
  input [7:0] move,           // encoded 1-hot move to perform
  output reg [4:0] mv_indx,   // "address" to access next move
  input [15:0] cmd_UART,      // cmd from UART_wrapper
  input cmd_rdy_UART,         // cmd_rdy from UART_wrapper
  output [15:0] cmd,          // multiplexed cmd to cmd_proc
  output cmd_rdy,             // cmd_rdy signal to cmd_proc
  input clr_cmd_rdy,          // from cmd_proc (goes to UART_wrapper too)
  input send_resp,            // lets us know cmd_proc is done with the move command
  output [7:0] resp           // either 0xA5 (done) or 0x5A (in progress)
);

  // Declare states
  typedef enum reg [2:0] {IDLE, Y_MOV, CMD1, X_MOV, CMD2} state_t;
  state_t next_state, state;

  // SM outputs
  reg [15:0] knight_CMD;
  reg sel_UART; //select UART mus inputs if tourcmd isnt activated
  reg clr_cntr, inc_cntr; //state machine outputs to clear mv_indx and to inc mv_indx
  reg tourCMD_rdy;

  // Muxes to select UART or knight's tour functionality

  //MUX sekect between UART and tourCMd functionality
  assign cmd = (sel_UART) ? cmd_UART : knight_CMD;
  assign cmd_rdy = (sel_UART) ? cmd_rdy_UART : tourCMD_rdy;

  //assign resp mux depending on if in UART mode (A5), intermediate tourCMD (5A) or if tourCMD is done (A5)
  assign resp = (sel_UART || (mv_indx == 5'd23)) ? 8'hA5 : 8'h5A;

  // mv_indx register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      mv_indx <= 5'h00;
    else if (clr_cntr)
      mv_indx <= 5'h00;
    else if (inc_cntr)
      mv_indx <= mv_indx + 1;
  end

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // State Machine Logic
  always_comb begin
    // Initialize outputs
    clr_cntr = 0;
    inc_cntr = 0;
    sel_UART = 0;
    knight_CMD = 16'hxxxx;
    tourCMD_rdy = 0;
    next_state = state;

    case (state)
      IDLE: begin
        sel_UART = 1; //keep uart mode and keep mv_indx = 0
        clr_cntr = 1;
        if (start_tour)
          next_state = Y_MOV; //starting tourCMD
      end

      Y_MOV: begin
        knight_CMD = (move & 8'h03) ? 16'h4002 : //(0000 0011) assigning +2y for move - 0 or 1
                     (move & 8'h84) ? 16'h4001 : //(1000 0100) assigning +1y for move - 2 or 7
                     (move & 8'h30) ? 16'h47F2 : 16'h47F1; //(0011 0000) assigning -2y if move - 4 or 5; else assigining -1y for the remaining moves
        tourCMD_rdy = 1; //assert cmd_rdy for cmd_proc
        if (clr_cmd_rdy)
          next_state = CMD1;
      end

      CMD1: begin //hold the command sent to cmd_proc unless send_resp is assserted 
		   knight_CMD = (move & 8'h03) ? 16'h4002 : //0000 0011
                     (move & 8'h84) ? 16'h4001 : //1000 0100
                     (move & 8'h30) ? 16'h47F2 : 16'h47F1; //0011 0000
			//tourCMD_rdy = 1;
        if (send_resp)
          next_state = X_MOV;
      end

      X_MOV: begin
        knight_CMD = (move & 8'hC0) ? 16'h5BF2 : //(1100 0000) assigning +2x for move - 6 or 7 
                     (move & 8'h21) ? 16'h5BF1 :   //(0010 0001) assigning +1x for move - 5 or 1 
                     (move & 8'h0C) ? 16'h53F2 : 16'h53F1; //(0000 1100)  assigning -2x for move - 2 or 3 
        tourCMD_rdy = 1;
        if (clr_cmd_rdy)
          next_state = CMD2;
      end

      CMD2: begin //hold command
		knight_CMD = (move & 8'hC0) ? 16'h5BF2 : //1100 0000
                     (move & 8'h21) ? 16'h5BF1 :   //0010 0001
                     (move & 8'h0C) ? 16'h53F2 : 16'h53F1; //0000 1100
		
		if (send_resp) begin
			inc_cntr = 1;
			if (mv_indx == 5'd23) begin // Nested if statement
				next_state = IDLE; //if (send_resp and move_indx = 23)
			end else begin
				next_state = Y_MOV; // if (send_resp and move_indx!-23)
			end
		end
      end
	  
	  default: begin
		next_state = state;
	  end
		
    endcase
  end

endmodule
