
module inert_intf_tb();

logic clk, rst_n;
logic moving, strt_cal;
logic lftIR, rghtIR;
logic SS_n, SCLK;
logic MISO, MOSI, INT;
logic rdy, cal_done;
logic [11:0] heading;


inert_intf inert_intf_INSTANCE(.clk(clk),.rst_n(rst_n),.strt_cal(strt_cal),.cal_done(cal_done),.heading(heading),
				.rdy(rdy),.lftIR(lftIR),.rghtIR(rghtIR),.SS_n(SS_n),.SCLK(SCLK),.MOSI(MOSI),
				.MISO(MISO),.INT(INT),.moving(moving));
SPI_iNEMO4 iSPI(.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),.INT(INT));

initial begin
	clk = 0;
	rst_n = 0;
	strt_cal = 0;
	moving = 1;
	lftIR = 0;
	rghtIR = 0;
	@(negedge clk);
	rst_n = 1 ;
	fork
		begin: timeout1
			repeat(1000000)@(posedge clk);
			$display("timeout error NEMO_setup");
			$stop();
		end
		
		begin 
			@(posedge iSPI.NEMO_setup);
			disable timeout1;
		end
	join
	@(negedge clk);
	strt_cal = 1;
	@(negedge clk);
	strt_cal = 0;
	
	fork
		begin: timeout2
			repeat(10000000)@(posedge clk);
			$display("timeout error");
			$stop();
		end
		
		begin 
			@(posedge cal_done);
			disable timeout2;
		end
	join
	
	repeat(8000000)@(posedge clk);
	
	$stop();
end

always
	#5 clk =~clk;
endmodule