module sponge_tb();
	// inputs
    logic clk;
    logic rst_n;
    logic go;
	logic done;

    // Outputs
    logic piezo;
    logic piezo_n;

    // Instantiate the Unit Under Test (UUT)
    sponge #(1)uut(
        .clk(clk),
        .rst_n(rst_n),
        .go(go),
        .piezo(piezo),
        .piezo_n(piezo_n)
    );


    // Clock generation
	always
	#10 clk = ~clk;


    // Initial block
    initial begin
        // Initialize Inputs
        rst_n = 0;
        go = 0;
		clk = 0;

        @(negedge clk)
        rst_n = 1; // Release reset
		
        // Sequence to start the module
        @(posedge clk);
        go = 1; // Activate 'go' signal to start playing
		#100;
        @(posedge clk);
        go = 0; // Deactivate 'go' to see normal behavior
		
		// Wait for done signal from sponge
		@(posedge uut.done);
		
		repeat(10) @(posedge clk); // Enough time after done signal to observe outputs

		$stop;
    end

endmodule