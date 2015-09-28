module uart_rcv(rx_rdy, rx_data, clk, rst_n, RX, clr_rx_rdy);
	//input, output signals
	output [7:0] rx_data;
	output reg rx_rdy;

	input clk, rst_n, RX, clr_rx_rdy;
	
	//internal signals
	logic load, shift, transmitting, set_ready, rx_nr, rx_rd;
	reg [11:0] baud_cnt;
	reg [3:0] bit_cnt;
	reg [9:0] rx_shft;

	// define state names
	typedef enum reg[1:0] {idle, first, rest} state_t;
	state_t state, next_state;

	// double-flopped for meta-stability
	always @(posedge clk, negedge rst_n)
		if(!rst_n)begin
			rx_nr<=1;
			rx_rd<=1;
		end
		else begin
			rx_nr<=RX;
			rx_rd<=rx_nr;
		end
	

   	//Transmission counter
	always @(posedge clk)
		if(load)
			bit_cnt<=1'h0;
		else if(shift)
			bit_cnt<=bit_cnt+1;
	

   	 //12 bit counter for timing
   	 always @(posedge clk)
		if(load)
			baud_cnt<=3'h0;
		else if(shift)
			baud_cnt<=3'h0;
		else if(transmitting)
			baud_cnt<=baud_cnt+1;
	 

	//reciever shift register
	always @(posedge clk, negedge rst_n)
		if(!rst_n)
			rx_shft<=10'h000;
		else if(shift)
			rx_shft<= {rx_rd,rx_shft[9:1]}; //place input into MSB of shift reg
		else if(load)
			rx_shft<=10'h000;

	//data is the middle 8 bits
	assign rx_data = rx_shft[8:1];
	 
	//state flop
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			state<=idle;
		else
			state<=next_state;  	

	//state machine
	always_comb begin
		load=0;
		shift=0;
		transmitting=0;
		set_ready=0;
		next_state=idle;
		
		case(state)
			idle: if(!rx_rd)begin //leave idle on negedge of rx_rd
				next_state=first;
				load=1;
			end
			first: if(baud_cnt==1302)begin //done reading start bit
					next_state=rest;
					shift=1;
				end
				else begin
					transmitting=1; //tells baud cnt to count
					next_state=first; //stay in state
				end

			default: if(bit_cnt==10) //leave if done with receiving all bits
					set_ready=1;
				 else if(baud_cnt==2604) begin  //shift in the middle of each bit
					shift=1;
					next_state=rest;
				 end
				 else begin
					transmitting=1; //tells baud cnt to count
					next_state=rest;
				 end

		endcase



	end


	//output done flop
	always @(posedge clk, negedge rst_n)
		if(!rst_n)
			rx_rdy<=0;
		else if(set_ready)
			rx_rdy<=1;
		else if(clr_rx_rdy)
			rx_rdy<=0;


endmodule
