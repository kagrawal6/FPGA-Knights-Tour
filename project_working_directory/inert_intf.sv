//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.  In  //
// this application we only use Z-axis gyro for   //
// heading of robot.  Fusion correction comes    //
// from "gaurdrail" signals lftIR/rghtIR.       //
/////////////////////////////////////////////////
//`timescale 1ns/1ps
module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,lftIR,
                  rghtIR,SS_n,SCLK,MOSI,MISO,INT,moving);

  parameter FAST_SIM = 1;	// used to speed up simulation
  
  input clk, rst_n;
  input MISO;					// SPI input from inertial sensor
  input INT;					// goes high when measurement ready
  input strt_cal;				// initiate claibration of yaw readings
  input moving;					// Only integrate yaw when going
  input lftIR,rghtIR;			// gaurdrail sensors
  
  output cal_done;				// pulses high for 1 clock when calibration done
  output signed [11:0] heading;	// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
  output rdy;					// goes high for 1 clock when new outputs ready (from inertial_integrator)
  output SS_n,SCLK,MOSI;		// SPI outputs


  //////////////////////////////////
  // Declare any internal signal //
  ////////////////////////////////
  logic vld;		// vld yaw_rt provided to inertial_integrator
  logic pre_vld;
  
  logic done, snd;
  logic [15:0] cmd;
  logic [15:0] resp;
  
  SPI_mnrch iSPI_mnrch (.clk(clk), .rst_n(rst_n), .SS_n(SS_n),  .SCLK(SCLK), 
					.MOSI(MOSI), .MISO(MISO),  .snd(snd),.cmd(cmd),
					 .done(done), .resp(resp));
					 
	logic cap_yaw_high;
	logic cap_yaw_low;
	logic [15:0] yaw_rt;
	
	typedef enum logic [2:0] {INIT1, INIT2, INIT3, WAIT, LOW, HIGH} state_t;
	state_t state, next_state;
	
	logic [15:0] timer16;
	
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			timer16 <= 0;
		else 
			timer16 <= timer16 + 1;
	end 
	
	// INT SYNCH
	logic INT_FF1, INT_FF2;
	
	always_ff @(posedge clk , negedge rst_n) begin
		if (!rst_n) begin
		INT_FF1 <= 0;
		INT_FF2 <= 0;
		end
		else begin
		INT_FF1 <= INT;
		INT_FF2 <= INT_FF1;
		end
	end

	//FSM FLOP
	always_ff@(posedge clk, negedge rst_n) begin
		if (!rst_n) 
			state <= INIT1;
		else
			state <= next_state;
	end 
	// HOLDING REG FOR YAW LOW
	logic [7:0] yaw_low; 
	always_ff@ (posedge clk, negedge rst_n) begin
		if (!rst_n)
			yaw_low <= 0;
		else if (cap_yaw_low)
			yaw_low <= resp[7:0];
	end
	//HOLDING REG FOR YAW HIGH
	logic [7:0] yaw_high; 
	always_ff@ (posedge clk, negedge rst_n) begin
		if (!rst_n)
			yaw_high <= 0;
		else if (cap_yaw_high)
			yaw_high <= resp[7:0];
	end
	
	assign yaw_rt = {yaw_high , yaw_low};
		
	logic clr_vld;
	//STATE TRANSISTION LOGIC
	always_comb begin
		next_state = state;
		clr_vld = 0;
		pre_vld = 0;
		snd = 0;
		cap_yaw_high = 0;
		cap_yaw_low = 0;
		cmd = 0;
		case (state)
			INIT1: begin
				clr_vld = 1;
				cmd = 16'h0D02;
				if (&timer16) begin
					snd = 1;
					next_state = INIT2;
				end 
			end
			INIT2: begin
				cmd = 16'h1160;
				if(done) begin
					snd = 1;
					next_state = INIT3;
				end 
				
			end
			INIT3: begin
				cmd = 16'h1440;
				if (done) begin
					snd = 1;
					next_state = WAIT;
				end 
			end
			WAIT: begin
				cmd = 16'hA600;
				clr_vld = 1;
				if (INT_FF2) begin
					snd = 1;
					next_state = LOW;
				end
			end
			LOW: begin
				cmd = 16'hA700;
				if (done) begin
					cap_yaw_low = 1;
					snd = 1;
					next_state = HIGH;
				end
			end
			HIGH: begin
				if (done) begin
					cap_yaw_high = 1;
					pre_vld = 1;
					next_state = WAIT;
				end
			end
		endcase
	end
	
	// SR FLOP for VLD.
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			vld <= 0;
		else if (clr_vld)
			vld <= 0;
		else if (pre_vld)
			vld <= 1;
	end

 
  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and acceleration info and produces a heading reading         //
  /////////////////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),.vld(vld),
                           .rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),.lftIR(lftIR),
                           .rghtIR(rghtIR),.heading(heading));
						   

endmodule
	  