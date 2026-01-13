/////////////////////////////////////////////////////
///////// Testbench for tour simulation /////////////
/////////   without any prior moves     /////////////
/////////////////////////////////////////////////////
module KnightsTour_tb_tour_wo_cmd();
	import  tb_tasks::*;

	localparam FAST_SIM = 1;


	/////////////////////////////
	// Stimulus of type reg //
	/////////////////////////
	reg clk, RST_n;
	reg [15:0] cmd;
	reg send_cmd;

	///////////////////////////////////
	// Declare any internal signals //
	/////////////////////////////////
	wire SS_n,SCLK,MOSI,MISO,INT;
	wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
	wire TX_RX, RX_TX;
	logic cmd_sent;
	logic resp_rdy;
	logic [7:0] resp;
	wire IR_en;
	wire lftIR_n,rghtIR_n,cntrIR_n;

	//////////////////////
	// Instantiate DUT //
	////////////////////
	KnightsTour iDUT(.clk(clk), .RST_n(RST_n), .SS_n(SS_n), .SCLK(SCLK),
					.MOSI(MOSI), .MISO(MISO), .INT(INT), .lftPWM1(lftPWM1),
					.lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
					.RX(TX_RX), .TX(RX_TX), .piezo(piezo), .piezo_n(piezo_n),
					.IR_en(IR_en), .lftIR_n(lftIR_n), .rghtIR_n(rghtIR_n),
					.cntrIR_n(cntrIR_n));
					
	/////////////////////////////////////////////////////
	// Instantiate RemoteComm to send commands to DUT //
	///////////////////////////////////////////////////
	RemoteComm iRMT(.clk(clk), .rst_n(RST_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd),
				.snd_cmd(send_cmd), .cmd_snt(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
					
	//////////////////////////////////////////////////////
	// Instantiate model of Knight Physics (and board) //
	////////////////////////////////////////////////////
	KnightPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
						.MOSI(MOSI),.INT(INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
						.rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.IR_en(IR_en),
						.lftIR_n(lftIR_n),.rghtIR_n(rghtIR_n),.cntrIR_n(cntrIR_n)); 
	initial begin
	
		// Initializing inputs
		initialize(.clk(clk), .RST_n(RST_n), .send_cmd(send_cmd)); 
		
		// Checking for NEMO_setup
		wait_for_NEMO_setup( .NEMO_setup(iPHYS.iNEMO.NEMO_setup), .clk(clk));
		
		// Calibration command
		
		SendCmd(.host_cmd(16'h2000),.cmd(cmd), .send_cmd(send_cmd),.clk(clk));
		// Checking for cal_done
		wait_for_cal_done(.cal_done(iDUT.cal_done), .clk(clk));
		
		// Checking for resp ready
		ChkPosAck( .resp_rdy(resp_rdy), .resp(iDUT.resp), .clk(clk) );
		repeat(100000)@(posedge clk);
		
		/////////////////////////
		// Testing Tour Logic //
		////////////////////////
		SendCmd(.host_cmd(16'h6022),.cmd(cmd), .send_cmd(send_cmd),.clk(clk));
		
		// Calling tour task to start knights_tour
		tour_start(.clks2wait(1000000000), .clk(clk), .resp(iDUT.resp), .resp_rdy(resp_rdy), .xx(iPHYS.xx), .yy(iPHYS.yy), .move(iDUT.iTL.move), .omega_sum(iPHYS.omega_sum), .heading_robot(iPHYS.heading_robot));
		

		$display("YAHOO! TESTS PASSED!");
		$stop();
		
		

	end
  
  always
    #5 clk = ~clk;

  
endmodule

	
