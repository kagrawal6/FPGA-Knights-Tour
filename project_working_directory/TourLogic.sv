//`timescale 1ns/1ps
module TourLogic(clk,rst_n,x_start,y_start,go,done,indx,move);

  input clk,rst_n;				// 50MHz clock and active low asynch reset
  input [2:0] x_start, y_start;	// starting position on 5x5 board
  input go;						// initiate calculation of solution
  input [4:0] indx;				// used to specify index of move to read out
  output logic done;			// pulses high for 1 clock when solution complete
  output logic[7:0] move;			// the move addressed by indx (1 of 24 moves)
  
  ////////////////////////////////////////
  // Declare needed internal registers //
  //////////////////////////////////////
  
  /*<< some internal registers to consider: >>
  << These match the variables used in knightsTourSM.pl >>*/
  reg board[0:4][0:4];		// keeps track if position visited
  reg [7:0] last_move[0:23];		// last move tried from this spot
  //reg [7:0] poss_moves[0:23];		// stores possible moves from this position as 8-bit one hot
  reg [7:0] move_try;				// one hot encoding of move we will try next
  reg [4:0] move_num;				// keeps track of move we are on
  reg [2:0] xx,yy;					// current x & y position  
 /*
  << 2-D array of 5-bit vectors that keep track of where on the board the knight
     has visited.  Will be reduced to 1-bit boolean after debug phase >>
  << 1-D array (of size 24) to keep track of last move taken from each move index >>
  << 1-D array (of size 24) to keep track of possible moves from each move index >>
  << move_try ... not sure you need this.  I had this to hold move I would try next >>
  << move number...when you have moved 24 times you are done.  Decrement when backing up >>
  << xx, yy couple of 3-bit vectors that represent the current x/y coordinates of the knight>>
  
  << below I am giving you an implementation of the one of the register structures you have >>
  << to infer (board[][]).  You need to implement the rest, and the controlling SM >>*/
  ///////////////////////////////////////////////////
  // The board memory structure keeps track of where 
  // the knight has already visited.  Initially this 
  // should be a 5x5 array of 5-bit numbers to store
  // the move number (helpful for debug).  Later it 
  // can be reduced to a single bit (visited or not)
  ////////////////////////////////////////////////	 
  logic calculate_possibilities; 
  logic try_next;
  logic zero, init, update_position, backup;
  reg [2:0] nxt_xx,nxt_yy;	
  always_ff @(posedge clk)
    if (zero)
	  board <= '{'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0}};
	else if (init)
	  board[x_start][y_start] <= 5'h1;	// mark starting position
	else if (update_position)
	  board[nxt_xx][nxt_yy] <= 1;	// mark as visited
	else if (backup)
	  board[xx][yy] <= 5'h0;			// mark as unvisited
  
  
  //<< Your magic occurs here >>
  // XX YY FLOP
	always_ff @ (posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			xx <= 0;
			yy <= 0;
		end else if (init) begin
			xx <= x_start;
			yy <= y_start;
		end else if (update_position) begin
			xx <= nxt_xx;
			yy <= nxt_yy;
		end else if (backup) begin
			xx <= nxt_xx;
			yy <= nxt_yy;
		end
	end
	//POSS MOVE FLOP
	// always_ff @(posedge clk)  begin
	// 	if (calculate_possibilities) begin
	// 		poss_moves[move_num] <= calc_poss(xx ,yy);
	// 	end
	// end
	// MOVE NUM FLOP
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			move_num <= 0;
		end
		else if (zero) begin
			move_num <= 0;
		end
		else if (update_position) begin
			move_num <= move_num + 1;
		end
		else if (backup) begin
			move_num <= move_num - 1;
		end
	end
	// MOVE TRY FLOP
	always_ff @(posedge clk)
		if (init) begin
			move_try <= 8'h01;
		end
		else if (calculate_possibilities) 
			move_try <= 8'h01;
		else if (try_next) 
			move_try <= {move_try[6:0], 1'b0};
        else if (backup) begin
            move_try <= last_move[move_num-1] << 1;
        end
		
    
    always_ff @(posedge clk) begin
        if (zero) begin
            integer i;
            for (i = 0; i < 24; i++) begin
                last_move[i] <= 0;
            end
        end

        else if(update_position) begin
            last_move[move_num] <= move_try;
        end
    end
	
	typedef enum logic [2:0] {IDLE, GO, CALC_POSS, MOVE, BACKUP} state_t;
	state_t state, next_state;

	//FSM FLOP
	always_ff @ (posedge clk, negedge rst_n) begin
		if (!rst_n) 
			state <= IDLE;
		else
			state <= next_state;
	end

	//STATE TRANSITION LOGIC
	
	always_comb begin
		next_state = state;
        done = 0;
		nxt_xx = 0;
		nxt_yy = 0;
		init = 0;
		zero = 0;
		calculate_possibilities = 0;
		update_position = 0;
		try_next = 0;
        backup = 0;
		case (state)
			default : begin  //IDLE STATE
				if (go) begin
					zero = 1;
					next_state = GO;
				end
			end
            GO : begin
                init = 1;
                next_state = CALC_POSS;
            end
			CALC_POSS : begin
			calculate_possibilities = 1;
            next_state = MOVE;
			end
			MOVE : begin
				if ((|(calc_poss(xx, yy)& move_try)) & (board[xx  + off_x(move_try)][yy + off_y(move_try)] == 0)) begin
					update_position = 1;
                    if (move_num == 5'd23) begin
                        next_state = IDLE;
                        done = 1;
                    end
                    else begin
                        next_state = CALC_POSS;
                    end
					nxt_xx = xx + off_x(move_try);
					nxt_yy = yy + off_y(move_try);
					
                end 
                else if (move_try != 0)  begin
                    try_next = 1;
                end 
                else begin
					next_state = BACKUP;
				end
			end
			BACKUP : begin
                nxt_xx = xx - off_x(last_move[move_num-1]);
				nxt_yy = yy - off_y(last_move[move_num-1]);
				backup = 1;
                if(last_move[move_num-1] != 0) begin
				    next_state = MOVE;
                end
			end
		endcase
	end
	
	assign move = last_move[indx];
  
  
  
  function [7:0] calc_poss(input [2:0] xpos,ypos);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a packed byte of
	// all the possible moves (at least in bound) moves given
	// coordinates of Knight.
	/////////////////////////////////////////////////////
	logic move0, move1, move2, move3, move4, move5, move6, move7;
    move0 = (xpos <= 3 && ypos <= 2) ? 1 : 0;
	move1 = (xpos >= 1 && ypos <= 2) ? 1 : 0;
	move2 = (xpos >= 2 && ypos <= 3) ? 1 : 0;
	move3 = (xpos >= 2 && ypos >= 1) ? 1 : 0;
	move4 = (xpos >= 1 && ypos >= 2) ? 1 : 0;
	move5 = (xpos <= 3 && ypos >= 2) ? 1 : 0;
	move6 = (xpos <= 2 && ypos >= 1) ? 1 : 0;
	move7 = (xpos <= 2 && ypos <= 3) ? 1 : 0;
	calc_poss = {move7, move6, move5, move4, move3, move2, move1, move0};   
	return calc_poss;
  endfunction
  
  function signed [2:0] off_x(input [7:0] try);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a the x-offset
	// the Knight will move given the encoding of the move you
	// are going to try.  Can also be useful when backing up
	// by passing in last move you did try, and subtracting 
	// the resulting offset from xx
	/////////////////////////////////////////////////////
	    off_x = (try[0] | try[5]) ? 3'b001 :  // 1
                (try[7] | try[6]) ? 3'b010 :  // 2
                (try[2] | try[3]) ? 3'b110 :  // -2
                (try[1] | try[4]) ? 3'b111 :  // -1
                3'b000;  // Default case (if none of the conditions are true)
	return off_x;
  endfunction
  
  function signed [2:0] off_y(input [7:0] try);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a the y-offset
	// the Knight will move given the encoding of the move you
	// are going to try.  Can also be useful when backing up
	// by passing in last move you did try, and subtracting 
	// the resulting offset from yy
	/////////////////////////////////////////////////////
	    off_y = (try[2] | try[7]) ? 3'b001 :  // 1
                (try[1] | try[0]) ? 3'b010 :  // 2
                (try[4] | try[5]) ? 3'b110 :  // -2
                (try[3] | try[6]) ? 3'b111 :  // -1
                3'b000;  // Default case (if none of the conditions are true)
	return off_y;
  endfunction
  
endmodule
	  