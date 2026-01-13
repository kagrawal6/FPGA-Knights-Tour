//`timescale 1ns/1ps
module SPI_mnrch(clk,rst_n,SS_n,SCLK,MISO,MOSI,snd,done,resp,cmd);

  input clk,rst_n;						// clk and active low asynch reset
  input snd,MISO;						// initiate transaction with snd
  input [15:0] cmd;						// command/data to serf
  output reg SS_n, done;				// both done and SS_n implemented as set/reset flops
  output SCLK,MOSI;
  
  output [15:0] resp;					// parallel data of MISO from serf

  typedef enum logic[1:0] {IDLE,BITS,BACK_PORCH} state_t;
  
  state_t state,next_state;			// declare enumerated states
  reg [4:0] SCLK_div;
  reg [4:0] bit_cntr;
  reg [15:0] shft_reg;			// stores the output to be serialized on MOSI
  
 
  logic init;
  logic set_done, ld_SCLK_div;
  

  logic shft, SCLK_full;

//FSM FLOP
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;

//MISO MOSI REG
  always_ff @(posedge clk)
	if (init)
      shft_reg <= cmd;
    else if (shft)
      shft_reg <= {shft_reg[14:0],MISO};

// BIT COUNT REG
  always_ff @(posedge clk)
    if (init)
      bit_cntr <= 5'b00000;
    else if (shft)
      bit_cntr <= bit_cntr + 1'b1;

// SCLK REG
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  SCLK_div <= 5'b10111;
	else if (ld_SCLK_div)
      SCLK_div <= 5'b10111;
    else
      SCLK_div <= SCLK_div + 1'b1;

  assign SCLK = SCLK_div[4];		// div 32, SCLK normally high
  assign shft = (SCLK_div==5'b10001) ? 1'b1 : 1'b0;	// 2 clks after SCLK rise
  assign SCLK_full = &SCLK_div;	// SPI transaction over when SCLK is full
  
// SR FLOP WITH DONE
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  done <= 1'b0;
	else if (set_done)
	  done <= 1'b1;
	else if (init)
	  done <= 1'b0;
	  
// SS_N REG
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  SS_n <= 1'b1;
	else if (set_done)
	  SS_n <= 1'b1;
	else if (init)
	  SS_n <= 1'b0;
	  
// STATE TRANSITION LOGIC
  always_comb
    begin
      init = 0; // DEFALULTS 
      set_done = 0;
	  ld_SCLK_div = 0;
	  
	  next_state = IDLE;

      case (state)
        IDLE : begin
		  ld_SCLK_div = 1;
          if (snd) begin
		    init = 1;
            next_state = BITS;
		  end
        end
        BITS : begin
		  if (bit_cntr[4])
		    next_state = BACK_PORCH;
          else
            next_state = BITS;         
        end
        default : begin 	// this is BACK_PORCH
          if (SCLK_full)
		    begin
			  next_state = IDLE;
			  ld_SCLK_div = 1;	// inhibit fall of SCLK
			  set_done = 1;
			end
		  else
		    next_state = BACK_PORCH;
        end
      endcase
    end
  
  assign resp = shft_reg;		// when finished shft_reg will contain data read from serf
  assign MOSI = shft_reg[15];

endmodule 
