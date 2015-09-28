module A2D_intf(cnv_cmplt, res, a2d_SS_n, SCLK, MOSI, clk, rst_n, strt_cnv, chnnl, MISO);

//declare output, input signals
output logic cnv_cmplt, a2d_SS_n, SCLK, MOSI;
output logic [11:0] res;

input logic clk,rst_n, strt_cnv, MISO;
input logic [2:0] chnnl;

//internal signals
logic [4:0] SCLK_cnt;
logic [5:0] trans_cnt;
logic shift, clr_cnt, load, set_cnv_cmplt, ready_shift;
logic[15:0] shft_reg, shft_reg_inpt, cmd;

//define state names
typedef enum reg[1:0] {idle, send, last} state_t;
state_t state, next_state;


//counter used to set serial clock
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		SCLK_cnt<=5'b11111;
	else if(a2d_SS_n)
		SCLK_cnt<=5'b11111;
	else if(!a2d_SS_n)	
		SCLK_cnt<=SCLK_cnt+1;

//assign cmd signal
assign cmd = {2'b00, chnnl, 11'h000};

//serial clock
assign SCLK = SCLK_cnt[4];

//assign shift signal
assign shift = &SCLK_cnt[4:1] & !SCLK_cnt[0];

//assign signal from SPI mux
assign shft_reg_inpt = (load)	? cmd[15:0] :
		       (shift)	? {shft_reg[14:0],MISO} :
				shft_reg;

//assign res to the lower 12 bits of shft_reg
assign res = ~shft_reg[11:0];

//count transactions
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		trans_cnt<=0;
	else if(clr_cnt)
		trans_cnt<=0;
	else if(shift)	
		trans_cnt<=trans_cnt+1;

//SPI shift register
always@(posedge clk, negedge rst_n)
	if(!rst_n)
		shft_reg<=16'h0000;
	else
		shft_reg<= shft_reg_inpt;

//assign MOSI to msb of shft_reg
assign MOSI = shft_reg[15];
	

//state machine
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		state<=idle;
	else
		state<=next_state;


//conv complete flop
always@(posedge clk, negedge rst_n)
	if(!rst_n)
		cnv_cmplt<=0;
	else if(strt_cnv)
		cnv_cmplt<=0;
	else if(set_cnv_cmplt)
		cnv_cmplt<=1;



always_comb begin

	next_state=idle;
	clr_cnt=0;
	a2d_SS_n=1;
	load=0;
	set_cnv_cmplt=0;
	ready_shift=0;
	
	case(state)
		//wait until strt_cnv to get out of idle
		idle: if(strt_cnv)begin
				next_state= send;
				clr_cnt=1; //refesh transaction count
				a2d_SS_n=0;
				load=1;
			end
		
		send: if(trans_cnt[5])begin  //if there have been 16 transactions
				next_state = last;
				a2d_SS_n=0;  //assert a2d_SS_n to indicate that we wish to send the signal (activates SCLK)
    			end
     		        else begin
				next_state=send; 
				a2d_SS_n=0;
      		      	end
		
		default: 
			if(SCLK_cnt==3)
				set_cnv_cmplt=1;
			else begin  //wait until SCLK count equals 4, otherwise stay here
				a2d_SS_n=0;
				next_state=last;
			end	
	endcase

end

endmodule
