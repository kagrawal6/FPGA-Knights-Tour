//`timescale 1ns/1ps
module RemoteComm(
    input clk,                 // System clock
    input rst_n,               // Active-low reset 
    input snd_cmd,             // Signal to initiate command transmission
    input [15:0] cmd,          // 16-bit command to be sent over UART
    input RX,                  // UART receive line
    output logic cmd_snt,      // Output signal indicating command has been fully sent
    output TX,                  // UART transmit line
    output resp_rdy,
    output [7:0] resp
);
    
    // Define states for transmitting high and low bytes
    typedef enum logic [1:0] {IDLE, HIGH, LOW} state_t;
    state_t curr_state, nxt_state; // Current and next state variables
    
    // Internal signals
    logic trmt;                    // Transmission enable signal for UART
    logic clr_rx_rdy;              // Clear receive ready signal (for unused receive functionality)
    logic [7:0] tx_data;           // Byte to transmit over UART
    logic tx_done;                 // Transmission done signal from UART
    
    logic sel_high;                // Selector for high byte of command
    logic set_cmd_snt;             // Signal to indicate command sent status
    logic [7:0] low_byte;          // Stores the lower 8 bits of the command
    

    // UART instance for handling data transmission over UART
    UART uart_inst (
        .clk(clk),
        .rst_n(rst_n),
        .RX(RX),
        .TX(TX),
        .rx_rdy(resp_rdy),           // Not used
        .clr_rx_rdy(clr_rx_rdy),
        .rx_data(resp),          
        .trmt(trmt),
        .tx_data(tx_data),
        .tx_done(tx_done)
    );

    // Capture lower byte of command when snd_cmd is high
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            low_byte <= 8'b00000000; // Reset low byte
        else if (snd_cmd)
            low_byte <= cmd[7:0];    // Store low byte of command
    end

    // Multiplexer to control tx_data; sends high or low byte based on sel_high
    assign tx_data = (sel_high) ? cmd[15:8] : low_byte;

    // Combinational logic for state transitions and signal control
    always_comb begin
        nxt_state = curr_state; // Default: remain in current state
        trmt = 1'b0;            // Default: disable transmission
        sel_high = 1'b0;        // Default: select low byte
        set_cmd_snt = 1'b0;     // Default: command not yet fully sent

        // State machine to control command byte transmission
        case (curr_state)
            IDLE: begin
                if (snd_cmd) begin
                    sel_high = 1;      // Start with high byte
                    trmt = 1;          // Enable transmission
                    nxt_state = HIGH;  // Move to HIGH state
                end
            end
            
            HIGH: begin
                sel_high = 1'b1;       // Keep high byte selected
                if (tx_done) begin
                    sel_high = 0;      // Switch to low byte
                    trmt = 1;          // Enable transmission
                    nxt_state = LOW;   // Move to LOW state
                end
            end
            
            LOW: begin
                if (tx_done) begin
                    set_cmd_snt = 1;   // Indicate command sent
                    nxt_state = IDLE;  // Return to IDLE state
                end
            end
            
            default: 
                nxt_state = IDLE;      // Default state
        endcase
    end

    // State register to hold current state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            curr_state <= IDLE;        // Reset to IDLE on reset
        else
            curr_state <= nxt_state;   // Update state
    end

    // Control for cmd_snt signal, indicating full command transmission
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cmd_snt <= 1'b0;           // Reset command sent indicator
        else if (snd_cmd)
            cmd_snt <= 1'b0;           // Clear cmd_snt on new command
        else if (set_cmd_snt)
            cmd_snt <= 1'b1;           // Set cmd_snt when command is fully sent
    end

endmodule
