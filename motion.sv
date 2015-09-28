module motion(addr, strt_cnv, lft, rht, IR_out_en, IR_mid_en, IR_in_en, res, cnv_cmplt, go, clk, rst_n);

//input/output signals
output reg[10:0] lft, rht;
output reg[2:0] addr;
output reg strt_cnv, IR_out_en, IR_mid_en, IR_in_en;
input[11:0] res;
input cnv_cmplt, go, clk, rst_n;

//internal signals
logic[12:0] tmr;
logic[2:0] chnnl;
logic[1:0] itg_cnt;
logic rst_chnnl, inc_chnnl, clr_tmr, inc_itg_cnt, wrt_en_Intgrl, wrt_en_Icomp, wrt_en_Pcomp,
			wrt_en_Accum, wrt_en_rht, wrt_en_lft, wrt_en_Error, clr_accum, intg_en;



//internal signals for ALU
localparam Pterm = 14'h37e0;
localparam Iterm = 12'h380;
logic[15:0] dst;
logic[15:0] Accum, Pcomp;
//logic[13:0] Pterm;
logic[11:0] Fwd, Error, Intgrl, Icomp;
logic multiply, sub, mult2, mult4, saturate, PWM_sig, IR_en;

typedef enum reg[3:0] {IDLE, RDY, STRT_CNV_1, RHT_ACCUM, STRT_CNV_2, CALC_INTGRL, 
				CALC_ICOMP, CALC_PCOMP, CALC_ACCUM_1, CALC_RHT, CALC_ACCUM_2, CALC_LFT} state_t;
state_t state, nxt_state;

typedef enum reg[2:0] {ACCUM, ITERM, ERROR0, ERROR1, FWD} src1_sel_sig;
src1_sel_sig src1_sel;

typedef enum reg[2:0] {A2D_RES, INTGRL, ICOMP, PCOMP, PTERM} src0_sel_sig;
src0_sel_sig src0_sel;


pwm1 ir_pwm(.PWM_sig(PWM_sig), .rst_n(rst_n), .clk(clk));
 

//instantiate ALU
alu my_ALU(.dst(dst), .src1sel(src1_sel), .src0sel(src0_sel), .accum(Accum), .pcomp(Pcomp), .pterm(Pterm), 
		   .fwd(Fwd), .a2d_res(res), .error(Error), .intgrl(Intgrl), .icomp(Icomp), .iterm(Iterm), .multiply(multiply),
		   .sub(sub), .mult2(mult2), .mult4(mult4), .saturate(saturate));



//Digital Core Timer
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		tmr<=0;
	else if(clr_tmr)
		tmr<=0;
	else
		tmr<=tmr+1;



//chnnl counter
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		chnnl<=3'h0;
	else if(rst_chnnl)
		chnnl<=3'h0;
	else if(inc_chnnl)
		chnnl<=chnnl+1;


// Integral counter (every 4 iterations)
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		 itg_cnt <= 2'b00;
	else if(inc_itg_cnt)
		 itg_cnt <= itg_cnt + 1'b1;

// to avoid confusion, we'll make a signal wrt_en_Intgrl so that our write_enable blocks are consistent
assign wrt_en_Intgrl = (&itg_cnt) & intg_en ;



// for incrementing Fwd
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		Fwd <= 12'h000;
	else if (~go) // if go deasserted Fwd knocked down so
		Fwd <= 12'b000; // we accelerate from zero on next start.
	else if (wrt_en_Intgrl & ~&Fwd[10:8]) // 43.75% full speed
		Fwd <= Fwd + 1'b1; // only write back 1 of 4 calc cycles

// write enable Accum
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		Accum <= 16'h0000;
	else if(clr_accum)
		Accum <= 16'h0000;
	else if(wrt_en_Accum)
		Accum <= dst;

// write enable Error
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		Error <= 12'h000;
	else if(wrt_en_Error)
		Error <= dst[11:0];

// write enable Intgrl
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		Intgrl <= 12'h000;
	else if(wrt_en_Intgrl) //only writes once every 4 clock cycles
		Intgrl <= dst[11:0];

// write enable Icomp
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		Icomp <= 12'h000;
	else if(wrt_en_Icomp)
		Icomp <= dst[11:0];

// write enable Pcomp
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		Pcomp <= 16'h0000;
	else if(wrt_en_Pcomp)
		Pcomp <= dst;

// to set left motor
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		lft <= 12'h000;
	else if (!go)
		lft <= 12'h000;
	else if (wrt_en_lft)
		lft <= dst[11:1];

// to set right motor
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		rht <= 12'h000;
	else if (!go)
		rht <= 12'h000;
	else if (wrt_en_rht)
		rht <= dst[11:1];




//assign decoding
assign addr = 	(chnnl == 3'b000) ? 3'b001:
		(chnnl == 3'b001) ? 3'b000:
		(chnnl == 3'b010) ? 3'b100:
		(chnnl == 3'b011) ? 3'b010:
		(chnnl == 3'b100) ? 3'b011:
		3'b111;


always @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;

always_comb begin
	//default outputs
	nxt_state = IDLE;
	strt_cnv = 1'b0;
	clr_tmr = 1'b0;
	rst_chnnl =1'b0;
	inc_chnnl = 1'b0;
	mult2 = 1'b0;
	mult4 = 1'b0;
	multiply = 1'b0;
	sub = 1'b0;
	inc_itg_cnt = 1'b0;
	wrt_en_Accum = 1'b0;
	wrt_en_Error = 1'b0;
	wrt_en_Icomp = 1'b0;
	wrt_en_Pcomp = 1'b0;
	wrt_en_rht = 1'b0;
	wrt_en_lft = 1'b0;
	IR_en = 1'b0;
	src0_sel =A2D_RES;
	src1_sel = ACCUM;
	clr_accum = 1'b0;
	saturate = 1'b0;	
	intg_en =1'b0;

	case(state)
		IDLE:		if(go) begin
					nxt_state = RDY;
					rst_chnnl = 1'b1;
					clr_tmr = 1'b1;
					clr_accum=1'b1;
				        IR_en = 1'b1;
				end

		RDY:	begin
				IR_en = 1'b1;

				if(tmr == 4096) begin
					nxt_state = STRT_CNV_1;
					strt_cnv = 1'b1;
				end
				else begin
					nxt_state = RDY;			
				end
			end
		
		STRT_CNV_1:	begin
				IR_en = 1'b1;
			
				if(cnv_cmplt)begin
					wrt_en_Accum = 1'b1;
					inc_chnnl = 1'b1;
					nxt_state = RHT_ACCUM;
					clr_tmr = 1'b1;
					if(chnnl == 2)
						mult2 = 1'b1;
					else if(chnnl == 4)
						mult4 = 1'b1;
				end				
				else
					nxt_state = STRT_CNV_1;
			end


		RHT_ACCUM:	begin

				IR_en = 1'b1;

				if(tmr == 32)begin	
					nxt_state = STRT_CNV_2;
					strt_cnv = 1'b1;		
				end
				else
					nxt_state = RHT_ACCUM;
			end
			
		
		STRT_CNV_2:	if(cnv_cmplt)begin
					
					if(chnnl == 1) begin
						inc_chnnl=1'b1;
						wrt_en_Accum = 1'b1;
						sub = 1'b1;
						nxt_state=RDY;
					end
					else if(chnnl == 3) begin
						inc_chnnl=1'b1;
						wrt_en_Accum = 1'b1;
						mult2 = 1'b1;
						sub = 1'b1;
						nxt_state=RDY;
					end
					else if(chnnl == 5) begin
						wrt_en_Error = 1'b1;
						mult4 = 1'b1;
						sub = 1'b1;
						saturate = 1'b1;
						nxt_state=CALC_INTGRL;
					end
				end
				else begin
					nxt_state = STRT_CNV_2;
					IR_en = 1'b1;
				end	
		
	/*	LFT_ACCUM:	if(chnnl == 6) 	
					nxt_state = CALC_INTGRL;
				else					nxt_state = RDY;*/

		CALC_INTGRL:	begin
					nxt_state = CALC_ICOMP;
					saturate = 1'b1;
					src0_sel = INTGRL;
					src1_sel = ERROR1;
					intg_en =1'b1;
					//inc_itg_cnt = 1'b1;
					clr_tmr = 1'b1;
				end
		
		CALC_ICOMP:	begin
					multiply = 1'b1;
					src0_sel = INTGRL;
					src1_sel = ITERM;
					if(tmr[0]) begin
						nxt_state = CALC_PCOMP;
						wrt_en_Icomp = 1'b1;
					end
					else
					nxt_state= CALC_ICOMP;
					
				end
		
		CALC_PCOMP:	begin
					multiply = 1'b1;
					src0_sel = PTERM;
					src1_sel = ERROR0;
					if(tmr[0]) begin
						nxt_state = CALC_ACCUM_1;
						wrt_en_Pcomp = 1'b1;
					end
					else
					nxt_state=CALC_PCOMP;
				end
			
		CALC_ACCUM_1:	begin
					nxt_state = CALC_RHT;
					wrt_en_Accum = 1'b1;
					sub = 1'b1;
					src0_sel = PCOMP;
					src1_sel = FWD;
				end
		
		CALC_RHT:	begin
					nxt_state = CALC_ACCUM_2;
					wrt_en_rht = 1'b1;
					saturate = 1'b1;
					sub = 1'b1;
					src0_sel = ICOMP;
					src1_sel = ACCUM;
				end
		
		CALC_ACCUM_2:	begin
					nxt_state = CALC_LFT;
					wrt_en_Accum = 1'b1;
					src0_sel = PCOMP;
					src1_sel = FWD;
				end
		
		default:	begin
					//nxt_state = CALC_FWD;
					wrt_en_lft = 1'b1;
					saturate = 1;
					src0_sel = ICOMP;
					src1_sel = ACCUM;
					inc_itg_cnt = 1'b1;
				end
	

		//This will be covered in our Integral write_enable, since that only goes once every 4 loops
	/*	//CALC_FWD
		default:	begin
					if(&Fwd_cnt) 
						inc_Fwd = 1'b1;
					inc_Fwd_cnt = 1'b1;
				end */

	endcase

end

 

  assign IR_in_en = (IR_en && ~|chnnl[2:1]) ? PWM_sig : 1'b0; 
  assign IR_mid_en = (IR_en && ~chnnl[2] && chnnl[1]) ? PWM_sig : 1'b0; 
  assign IR_out_en = (IR_en && chnnl[2]) ? PWM_sig : 1'b0; 




endmodule	
					