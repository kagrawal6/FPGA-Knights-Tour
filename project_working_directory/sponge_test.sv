module sponge_test(
	input clk,
	input RST_n,
	input GO,
	output logic piezo,
	output logic piezo_n
);

// PB_release
// Internal Signals
logic go;
logic rst_n;

// Instantiating PB_release
PB_release iuut(.clk(clk), .rst_n(rst_n), .PB(GO), .released(go));

// Reset_synch
reset_synch iuut2(.clk(clk), .rst_n(rst_n), .RST_n(RST_n));

// Instantiating sponge
sponge #(0) iuut1 (.clk(clk), .rst_n(rst_n), .go(go), .piezo(piezo), .piezo_n(piezo_n));

endmodule