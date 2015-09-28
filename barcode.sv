module barcode(ID_vld, ID, BC, clr_ID_vld, clk, rst_n);

//define inputs, outputs
input logic BC, clr_ID_vld, clk, rst_n;
output logic[7:0] ID;
output logic ID_vld;

//define states to be used
typedef enum reg[2:0] {idle, get_time_info, wait_start, smpl, wait_high} state_t;
	state_t state, next_state;

logic BC_filtered, BC_FF0, BC_FF1, BC_FF2, BC_FF3, set, clr, start_timing_cnt, start_smpl_cnt, hold_cnt, shift, vld_en, start_bit;
logic[21:0] timing_cnt, smpl_cnt;
logic [3:0] bit_cnt;

//Flop 4 times and check BC input
always @(posedge clk, negedge rst_n)begin
	if(!rst_n)begin
		BC_FF0<=1;
		BC_FF1<=1;
		BC_FF2<=1;
		BC_FF3<=1;
	end
	/*if(&smpl_cnt)begin
		BC_FF0<=1;
		BC_FF1<=1;
		BC_FF2<=1;
		BC_FF3<=1;
	end*/
	else begin
		BC_FF0<=BC;
		BC_FF1<=BC_FF0;
		BC_FF2<=BC_FF1;
		BC_FF3<=BC_FF2;
	end
end

//sets and clears BC based on filter
assign set = BC_FF1&BC_FF2&BC_FF3;
assign clr = ~(BC_FF1|BC_FF2|BC_FF3);

//check input flops and signal the filtered BC reducing the noise
always @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		BC_filtered<=1'b1;
	else if(set)
		BC_filtered<=1'b1;
	else if(clr)
		BC_filtered<=1'b0;
end 

//counter used to find timing
always @(posedge clk, negedge rst_n)
		if(!rst_n)
			timing_cnt<=21'h000000;
		else if(start_timing_cnt)
			timing_cnt<=21'h000000;
		else if(!hold_cnt)
			timing_cnt<=timing_cnt+1;

//counter used to get samples
always @(posedge clk, negedge rst_n)
		if(!rst_n)
			smpl_cnt<=21'h000000;
		else if(start_smpl_cnt)
			smpl_cnt<=21'h000000;
		else
			smpl_cnt<=smpl_cnt+1;


//bit count
always @(posedge clk, negedge rst_n)
		if(!rst_n)
			bit_cnt<=3'h0;
		else if(start_bit)
			bit_cnt<=3'h0;
		else if(shift)
			bit_cnt<=bit_cnt+1;


//state machine flop
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		state=idle;
	else
		state=next_state;

//next state logic
always_comb begin
	//default outputs
	next_state=idle;
	start_timing_cnt=0;
	hold_cnt=1;
	start_smpl_cnt=0;
	shift=0;
	vld_en=1'b1;
        start_bit =0;
	case(state)
		idle:
			//get out of this state at negedge of BC, indicating start bit
			if(~BC_filtered) begin
				next_state=get_time_info;
				start_timing_cnt=1;
				hold_cnt=0;
			end
		get_time_info:
			//leave state when BC goes high
			if(BC_filtered)begin
				next_state=wait_start;
				start_smpl_cnt=1;
				start_bit=1;
			end
			//count period timing for the rest of the analog signal
			else begin
				next_state=get_time_info;
				hold_cnt=0;
			end
		wait_start:
			//if all 8 bits have been counted, go to idle
			if(bit_cnt==8)begin
				next_state=idle;
				vld_en=1'b1;
			end
			else if(&smpl_cnt) //checking for timeout
				next_state=idle;
			//if BC is still high (right before new bit), stay in this state
			else if(BC_filtered)
				next_state=wait_start;
			//go to state to sample the signal to shift				
			else begin
				next_state=smpl;
				start_smpl_cnt=1;
			end
		smpl:
			//if the amount of time has passed equal to the period length, shift in
			if(smpl_cnt==timing_cnt)begin
				next_state=wait_high;
				shift=1;
			end
			else
				next_state=smpl;
		default:
			//if BC is already high, go to wait for the next bit (bit is 1)
			if(BC_filtered)
				next_state=wait_start;
			else //otherwise wait until BC is high (bit is 0)
				next_state=wait_high;
	endcase

end


//ID flop that will shift in BC when signaled
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		ID<= 8'hFF;
	else if(clr_ID_vld)
		ID<= 8'hFF;
	else if(shift)
		ID<= {ID[6:0],BC_filtered};

//ID valid flop, triggered by an enable which indicated that 8 bits have been passed
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		ID_vld<=0;
	else if(clr_ID_vld)
		ID_vld<=0;
	else if((~|ID[7:6]) & vld_en)
		ID_vld<=1;

endmodule
