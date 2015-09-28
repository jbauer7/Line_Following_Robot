//////////////////
/// PWM Module with set duty cycle of 8c
//////////////////


module pwm1(PWM_sig, rst_n, clk);
    
    //declare input, output signals
    output reg PWM_sig;
    input clk, rst_n;
    localparam DUTY = 8'h8c;
  
    //internal signals  
    reg [7:0] cntr;  
    wire set_PWM, clr_PWM; 
    
   //cntr is always counting, gets all 1's on rst_n
   always @(posedge clk, negedge rst_n)begin
         if (!rst_n) cntr<=8'hff;
         else cntr<=cntr+1;
   end
   
   
   //PWM_sig will either be set to one, cleared to zero, or hold its value
   always @(posedge clk, negedge rst_n)begin
         if(!rst_n) PWM_sig <= 1'b0;
	 else if(clr_PWM) PWM_sig <=1'b0;
	 else if(set_PWM) PWM_sig <=1'b1;  
   end   
   
   // set PWM when ctr reaches its max
   assign set_PWM = &cntr;

   // clear PWM when ctr reaches given duty cycle
   assign clr_PWM = (cntr == DUTY) ? 1'b1 : 1'b0;

   
 endmodule

   
            


