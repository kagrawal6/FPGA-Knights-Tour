//`timescale 1ns/1ps
module sponge
#(parameter FAST_SIM = 0)
(
	input clk,
	input rst_n,
	input go,
	output logic piezo,
	output logic piezo_n
);

// Internal signal
logic clr; // Clear signal
logic done; // Done signal, asserted when song is finished playing

// Frequency counter logic
logic [15:0]freq_cnt; 
logic [15:0]frequency; // Register to specify the frequency of the note
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		freq_cnt <= 16'h0000;
	end else if(clr) begin 
		freq_cnt <= 16'h0000;
	end else if(freq_cnt >= frequency) begin 
		freq_cnt <= 16'h0000;
	end else begin
		freq_cnt <= freq_cnt + 1;
	end
end 

assign piezo = (freq_cnt < (frequency/2)) ? 1 : 0; // 50% duty cyle
assign piezo_n = (freq_cnt < (frequency/2)) ? 0 : 1;

// Duration counter logic 
logic [23:0]dur_cnt; // 24 bit register
logic [23:0]duration; // Register to specify the duration of note
logic [4:0]increment; // Increment register, either 1 or 16
logic note_over; // Flag to indicate that note is played for the required duration

// FAST_SIM generation
generate if(FAST_SIM) begin	
	assign increment = 16;
end else begin
	assign increment = 1;
end
endgenerate

// Counter
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		dur_cnt <= 24'h000000;
	end else if(clr) begin 
		dur_cnt <= 24'h000000;
	end else begin
		dur_cnt <= dur_cnt + increment;
	end
end

assign note_over = (dur_cnt == duration);


// Defining states
typedef enum reg [3:0] {IDLE, D7, E7, F7, A6, E7_1, D7_1, F7_1, D7_2}state_t;

state_t current_state, next_state;

// State transition logic
always_ff @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		current_state <= IDLE;
	end else begin
		current_state <= next_state;
	end
end

// Next state and Output logic
always_comb begin
	next_state = current_state;
	clr = 0;
	done = 0;
	frequency = 16'h0000;
	duration = 16'h0000;

	case(current_state)
		IDLE: begin
			if(go) begin
				next_state = D7;
				clr = 1;
			end
		end
			
		D7: begin
			frequency = 16'h5326;
			duration = 24'h800000; // duration = 2^23
			if (note_over) begin
				clr = 1;
				next_state = E7;
			end 
		end
		
		E7: begin
			frequency = 16'h4A11;
			duration = 24'h800000; // duration = 2^23
			if (note_over) begin
				clr = 1;
				next_state = F7;
			end 
		end
		
		F7: begin
			frequency = 16'h45E8;
			duration = 24'h800000; // duration = 2^23
			if (note_over) begin
				clr = 1;
				next_state = E7_1;
			end
		end
		
		E7_1: begin
			frequency = 16'h4A11;
			duration = 24'hC00000; // duration = 2^23 + 2^22
			if (note_over) begin
				clr = 1;
				next_state = F7_1;
			end
		end
		
		F7_1: begin
			frequency = 16'h45E8;
			duration = 24'h400000; // duration = 2^22
			if (note_over) begin
				clr = 1;
				next_state = D7_1;
			end
		end
			
		D7_1: begin
			frequency = 16'h5326;
			duration = 24'hC00000; // duration = 2^23 + 2^22
			if (note_over) begin
				clr = 1;
				next_state = A6;
			end
		end
		
		A6: begin
			frequency = 16'h6EFA;
			duration = 24'h400000; // duration = 2^22		
			if (note_over) begin
				clr = 1;
				next_state = D7_2;
			end
		end
			
		D7_2: begin
			frequency = 16'h5326;
			duration = 24'h800000; // duration = 2^23
			if (note_over) begin
				clr = 1;
				done = 1;
				next_state = IDLE;
			end
		end
		
		default: begin
			next_state = IDLE;
		end
			
	endcase

end
endmodule