//ALU used for line follower

module alu(dst,src1sel, accum, iterm, error, fwd,
               src0sel, a2d_res, intgrl, icomp, pcomp, pterm,
               mult2, mult4, sub, saturate, multiply);
    
		//ALU output    
		output [15:0]dst;
    
    //src1mux inputs
    input [2:0]src1sel;
    input [15:0] accum;
    input [11:0] iterm, error, fwd; 
    //src0mux inputs
    input [2:0] src0sel;
    input [11:0] a2d_res, intgrl, icomp;
    input [15:0] pcomp;
    input [13:0] pterm;
    //mult and saturation inputs
    input mult2, mult4, sub, saturate, multiply;
    
    //src1mux labels
    localparam ACCUM = 3'b000;
    localparam ITERM = 3'b001;
    localparam ERROR0 = 3'b010;
    localparam ERROR1 = 3'b011;
    localparam FWD = 3'b100;    
    //src0mux labels
    localparam ADRES = 3'b000;
    localparam INTG = 3'b001;
    localparam ICOM = 3'b010;
    localparam PCOM = 3'b011;
    localparam PTER = 3'b100;
    
	//mux output wires
	wire [15:0] src1, pre_src0, scaled_src0, src0;

	//adder output wires
	wire [15:0] add_o, add_o_s;
	
	//multplier outputwires
    	wire signed  [14:0] op1, op0;
    	wire signed  [29:0] mult_o;
    	wire [15:0] mult_o_s;//after saturation wire
    


    	//src1 mux
    	assign {src1} = (src1sel==ACCUM)  ? accum:
                    (src1sel==ITERM)  ? {4'b0000,iterm}:
                    (src1sel==ERROR0) ? {{4{error[11]}}, error}:
                    (src1sel==ERROR1) ? {{8{error[11]}}, error[11:4]}:
                    (src1sel==FWD)    ? {4'b0000, fwd}:
                                        16'h0000;    
                                        
                        
    	//src2 mux  
    	assign {pre_src0} = (src0sel==ADRES)  ? {4'b0000,a2d_res}:
                        (src0sel==INTG)   ? {{4{intgrl[11]}}, intgrl}:
                        (src0sel==ICOM)   ? {{4{icomp[11]}}, icomp}:
                        (src0sel==PCOM)   ? pcomp:
                        (src0sel==PTER)   ? {2'b00, pterm}:
                                          16'h0000;                                        
    
   
    	//bit shift                                    
    	assign {scaled_src0} = (mult4) ? pre_src0<<2:
                           (mult2) ? pre_src0<<1: pre_src0;
    

	//invert bits                     
  	assign {src0} = (sub) ?  ~scaled_src0 : scaled_src0;                   
                 
                 
  	//adder 
  	assign{add_o} = src1+src0+sub; //sub comples twos complment conversion weh sub sig is active
    

  	//signed multipcation
  	assign op1 = src1[14:0];
  	assign op0 = src0[14:0];
  	assign mult_o = op1*op0;
    	
    
    	//saturate adder
    	assign{add_o_s} = (saturate) ?
		      ((add_o[15])     ? 
                      ((&add_o[14:11]) ? add_o : 16'hf800) :
                      ((|add_o[14:11]) ? 16'h07ff : add_o)): add_o;
                      

    	//saturate multiplier 
     	assign{mult_o_s} = (mult_o[29])    ? 
                        ((&mult_o[27:26]) ? mult_o[27:12] : 16'h c000) :
                        ((|mult_o[27:26]) ? 16'h 3fff : mult_o[27:12]);   


   	//output mux
	assign{dst}  = (multiply) ? mult_o_s : add_o_s;                              
        
                                             
endmodule                                        
