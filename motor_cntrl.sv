module motor_cntrl(clk, rst_n, rht, lft, fwd_rht, fwd_lft, rev_rht, rev_lft);
//input, output signals
input clk, rst_n;
input [10:0] rht, lft;
output logic fwd_rht, fwd_lft, rev_rht, rev_lft;
//internal signals
logic [9:0] in_right, in_left; 
logic out_right, out_left;

//instantiate 2 pwm modules for right and left output signals (out_right and out_left will have the PWM signals)
pwm left_pwm(.PWM_sig(out_right), .duty(in_right), .rst_n(rst_n), .clk(clk));
pwm right_pwm(.PWM_sig(out_left), .duty(in_left), .rst_n(rst_n), .clk(clk));

//get the magnitude of the signal for duty cycle
assign in_right = (rht[10]) ?  ((~rht[9:0])+1) : rht[9:0]; //if negative, invert lower 10 bits and +1
assign in_left = (lft[10]) ?  ((~lft[9:0])+1) : lft[9:0]; //if negative, invert lower 10 bits and +1


assign fwd_lft = (lft == 11'h000) ? 1'b1 : 
		 (lft[10] == 1'b0) ? out_left: 1'b0; //if left signal is positive, give it the PWM sig

assign rev_lft = (lft == 11'h000) ? 1'b1 : 
		 (lft[10]) ?  out_left : 1'b0;  //if left signal is negative, give it the PWM sig

assign fwd_rht = (rht == 11'h000) ? 1'b1 : 
		 (rht[10] == 1'b0) ?  out_right : 1'b0; //if right signal is positive, give it the PWM sig

assign rev_rht = (rht == 11'h000) ? 1'b1 : 
		(rht[10]) ?  out_right : 1'b0; //if right signal is negative, give it the PWM sig

endmodule

