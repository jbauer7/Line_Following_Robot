module cmd_intf(buzz, buzz_n, clr_cmd_rdy, go, in_transit, clr_ID_vld, ID, ID_vld, cmd_rdy, OK2Move, cmd, clk, rst_n);

//input and output signals
output logic clr_cmd_rdy, go, in_transit, clr_ID_vld, buzz, buzz_n;
input[7:0] cmd, ID;
input ID_vld, cmd_rdy, OK2Move, clk, rst_n;

//internal signals
typedef enum reg {IDLE, CMD_CNTRL} state_t;
state_t state, nxt_state;

logic[12:0]count;
logic[5:0] dest_ID, dest_ID_inp;
logic buzz_en, inv_buzz, capture_ID, clr_in_transit, set_in_transit;

//start always blocks for buzzer
always @(posedge clk, negedge rst_n)
	if(!rst_n) 
		count <= 13'h0000;
	else if(buzz_en && count < 6250) 
		count <= count + 1;
	else if(buzz_en &&  count == 6250)
		count <= 13'h0000;
	
assign inv_buzz = (count == 6249) ? 1'b1: 1'b0;  //assert this invert buzz signal when count == 6249 (4 Hz)

always @(posedge clk, negedge rst_n)
	if(!rst_n) begin
		buzz <= 1'b0;
		buzz_n <= 1'b1;
	end
	else if(!buzz_en)begin
		buzz <=1'b0;
		buzz_n <=1'b1;
	end
	else if(inv_buzz) begin
		buzz <= ~buzz;
		buzz_n <= ~buzz_n;
	end
	else begin
		buzz <= buzz;
		buzz_n <= buzz_n;
	end

// always block for in_transit flop
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		in_transit <= 1'b0;
	else if(clr_in_transit)
		in_transit <= 1'b0;
	else if(set_in_transit)
		in_transit <= 1'b1;
	else
		in_transit <= in_transit;

assign buzz_en = in_transit & ~OK2Move;


assign dest_ID_inp = (capture_ID) ? cmd[5:0] : dest_ID;

//always block for dest_ID flop
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		dest_ID <= 6'h00;
	else if(capture_ID)
		dest_ID <= dest_ID_inp;
	


//conditional assign for go
assign go = in_transit & OK2Move;

/////
// Can do some other stuffs with capture_ID, 
/////

always @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;

always_comb begin
	//set default outputs
	nxt_state = IDLE;
	set_in_transit = 1'b0;
	clr_in_transit = 1'b0;
	capture_ID = 1'b0;
	clr_cmd_rdy = 1'b0;
	clr_ID_vld = 1'b0;

	case(state)
		IDLE: 		if(cmd_rdy && cmd[7:6] == 2'b01) begin //cmd != GO, stay in IDLE state
					nxt_state = CMD_CNTRL; // okay to go and incoming cmd signal says to go
					set_in_transit = 1'b1;
					capture_ID = 1'b1;
					clr_cmd_rdy = 1'b1;	
				end
		  		else if(cmd_rdy)
						clr_cmd_rdy = 1'b1; //if cmd_rdy was asserted, clear it
					
				

		//CMD_CNTRL state
		default:	if(cmd_rdy && cmd[7:6] == 2'b01) begin //cmd == GO, stay in moving state
					nxt_state = CMD_CNTRL;
					set_in_transit = 1'b1;
					capture_ID = 1'b1;
					clr_cmd_rdy = 1'b1;
				end
				//either cmd_rdy isn't okay and ID is invalid, or cmd_rdy is okay but we aren't 
				//getting cmd == GO or STOP and ID is invalid, so we stay here and do nothing
				else if((!cmd_rdy && !ID_vld) || (cmd_rdy && cmd[7:6] != 2'b01 && 
						cmd[7:6] != 2'b00 && !ID_vld)) begin
					nxt_state = CMD_CNTRL;
					if(cmd_rdy)
						clr_cmd_rdy = 1'b1; //if cmd_rdy was asserted, clear it
				end
				//either cmd_rdy isn't okay and we have a valid yet incorrect ID, or
				//we have cmd_rdy okay but cmd != GO or STOP and we have a valid yet incorrect ID
				//stay in this state
				else if((!cmd_rdy && ID_vld && ID[5:0] != dest_ID) || (cmd_rdy && cmd[7:6] != 2'b01 &&
						cmd[7:6] != 2'b00 && ID_vld && ID[5:0] != dest_ID)) begin
					nxt_state = CMD_CNTRL;
					clr_ID_vld = 1'b1;
					if(cmd_rdy)
						clr_cmd_rdy = 1'b1; //if cmd_rdy was asserted, clear it
				end
				//if cmd_rdy is okay and we're told to stop, go to IDLE and settle down
				else if(cmd_rdy && cmd[7:6] == 2'b00) begin
					clr_in_transit = 1'b1;
					clr_cmd_rdy = 1'b1;
				end
				//in any other scenario, cmd_rdy will either not be okay and we've reached our destination ID, or
				// cmd_rdy is okay and cmd != GO or STOP and we've reached our destination ID
				else begin
					clr_ID_vld = 1'b1;
					clr_in_transit = 1'b1;
					if(cmd_rdy)
						clr_cmd_rdy = 1'b1; //if cmd_rdy was asserted, clear it
				end

	endcase
end

endmodule
		

	