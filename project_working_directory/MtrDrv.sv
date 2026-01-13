//`timescale 1ns/1ps
module MtrDrv(input clk, input rst_n,input signed [10:0] lft_speed, input signed [10:0] rght_speed,
				output lftPWM1, output lftPWM2, output rghtPWM1, output rghtPWM2);

logic [10:0] lft_duty, rght_duty;

assign lft_duty = lft_speed + 11'h400;
assign rght_duty = rght_speed + 11'h400;

PWM11 lftPWM(.clk(clk), .rst_n(rst_n), .duty(lft_duty), .PWM_sig(lftPWM1),.PWM_sig_n(lftPWM2));
PWM11 rghtPWM(.clk(clk), .rst_n(rst_n), .duty(rght_duty), .PWM_sig(rghtPWM1),.PWM_sig_n(rghtPWM2));

endmodule