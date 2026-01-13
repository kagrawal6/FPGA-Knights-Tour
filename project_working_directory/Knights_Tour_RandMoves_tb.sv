/////////////////////////////////////////////////////
///////// Testbench for random moves sim ////////////
/////////////////////////////////////////////////////
module Knights_Tour_RandMoves_tb();
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


		/////////////////////////
        // Calibrating the DUT //
		/////////////////////////
		
		SendCmd(.host_cmd(16'h2000),.cmd(cmd), .send_cmd(send_cmd),.clk(clk));
		// Checking for cal_done
		wait_for_cal_done(.cal_done(iDUT.cal_done), .clk(clk));
		
		// Checking for resp ready
		ChkPosAck( .resp_rdy(resp_rdy), .resp(iDUT.resp), .clk(clk) );
		
        // wait 200000 clocks before sending next command
		repeat(200000) @(posedge clk);


		/////////////////////////////////////////////
		// Testing move east by one square command //
		/////////////////////////////////////////////
 
		SendCmd(.host_cmd(16'h4bf1),.cmd(cmd), .send_cmd(send_cmd),.clk(clk));
		
		// Checking if CnrtlIR gets triggered twice
		chkCntrlIR(.moves(2), .clk(clk), .cntrIR(iDUT.cntrIR));	
		
		// Checking for resp ready indicating the command is over
		ChkPosAck( .resp_rdy(resp_rdy), .resp(iDUT.resp), .clk(clk)  );

		// Checking if heading gets corrected
		chkHeading(.desired_heading(iDUT.iCMD.desired_heading), .heading(iDUT.heading), .clk(clk));
		
        // check if xx position reaches the expected range of values
		chkX(.clksToWait(1000000),.expected_x(15'h3680),  .clk(clk), .xx(iPHYS.xx) );
		
		// wait 200000 clocks before sending next command
		repeat(2000000) @(posedge clk);


		//////////////////////////////////////////////
		// Testing move north by two square command //
		//////////////////////////////////////////////
		SendCmd(.host_cmd(16'h4002),.cmd(cmd), .send_cmd(send_cmd),.clk(clk));
		
		// Checking if CnrtlIR gets triggered 4 times
		chkCntrlIR(.moves(4), .clk(clk), .cntrIR(iDUT.cntrIR));	
		
		// Checking for positive acknowledge
		ChkPosAck( .resp_rdy(resp_rdy), .resp(iDUT.resp), .clk(clk)  );

        // Checking if heading gets corrected
		chkHeading(.desired_heading(iDUT.iCMD.desired_heading), .heading(iDUT.heading), .clk(clk));
		
        // wait 200000 clocks before sending next command
		repeat(200000) @(posedge clk);


		//////////////////////////////////////////////
		// Testing move west by two square command //
		//////////////////////////////////////////////
		SendCmd(.host_cmd(16'h43f2),.cmd(cmd), .send_cmd(send_cmd),.clk(clk));
		
		// Checking for positive acknowledge
		ChkPosAck( .resp_rdy(resp_rdy), .resp(iDUT.resp), .clk(clk)  );
        
        // wait 200000 clocks before sending next command
		repeat(200000) @(posedge clk);


		//////////////////////////////////////////////
		// Testing move south by two square command //
		//////////////////////////////////////////////
		SendCmd(.host_cmd(16'h47f2),.cmd(cmd), .send_cmd(send_cmd),.clk(clk));
		
		
		// Checking for positive acknowledgement
		ChkPosAck( .resp_rdy(resp_rdy), .resp(iDUT.resp), .clk(clk)  );
		
		// wait 200000 clocks before sending next command
		repeat(200000) @(posedge clk);

		
		/////////////////////////////////////////////
		// Testing move east by one square command //
		/////////////////////////////////////////////
		SendCmd(.host_cmd(16'h4bf1),.cmd(cmd), .send_cmd(send_cmd),.clk(clk));
	
		
		// Checking for resp ready indicating the command is over
		ChkPosAck( .resp_rdy(resp_rdy), .resp(iDUT.resp), .clk(clk)  );

		// Waiting 150000 clocks to let waves fully settle
		repeat(150000) @(posedge clk); 	

        $stop();
	end	

    always
        #5 clk = ~clk;
endmodule