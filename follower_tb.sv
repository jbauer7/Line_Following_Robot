`timescale 1ns/1ps
module Follower_tb();

reg clk,rst_n;			// 50MHz clock and active low aysnch reset
reg OK2Move;
reg send_cmd,send_BC;
reg [7:0] cmd,Barcode;
//reg clr_buzz_cnt;

wire a2d_SS_n, SCLK, MISO, MOSI;
wire rev_rht, rev_lft, fwd_rht, fwd_lft;
wire IR_in_en, IR_mid_en, IR_out_en;
wire buzz, buzz_n, prox_en, BC, TX_dbg;
wire [7:0] led;
wire [3:0] buzz_cnt,buzz_cnt_n;
//wire [9:0] duty_fwd_rht,duty_fwd_lft,duty_rev_rht,duty_rev_lft;



////////////////////////////////////////////
// Declare any localparams that might    //
// improve code readability below here. //
/////////////////////////////////////////

//////////////////////
// Instantiate DUT //
////////////////////
Follower iDUT(.clk(clk),.RST_n(rst_n),.led(led),.a2d_SS_n(a2d_SS_n),
              .SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),.rev_rht(rev_rht),.rev_lft(rev_lft),.fwd_rht(fwd_rht),
			  .fwd_lft(fwd_lft),.IR_in_en(IR_in_en),.IR_mid_en(IR_mid_en),.IR_out_en(IR_out_en),
			  .in_transit(in_transit),.OK2Move(OK2Move),.buzz(buzz),.buzz_n(buzz_n),.RX(RX),.BC(BC));		
			  
//////////////////////////////////////////////////////
// Instantiate Model of A2D converter & IR sensors //
////////////////////////////////////////////////////
ADC128S iA2D(.clk(clk),.rst_n(rst_n),.SS_n(a2d_SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI));

/////////////////////////////////////////////////////////////////////////////////////
// Instantiate 8-bit UART transmitter (acts as Bluetooth module sending commands) //
///////////////////////////////////////////////////////////////////////////////////
UART_tx iTX(.clk(clk),.rst_n(rst_n),.TX(RX),.trmt(send_cmd),.tx_data(cmd),.tx_done(cmd_sent));

//////////////////////////////////////////////
// Instantiate barcode mimic (transmitter) //
////////////////////////////////////////////
barcode_mimic iMSTR(.clk(clk),.rst_n(rst_n),.period(22'h1000),.send(send_BC),.station_ID(Barcode),.BC_done(BC_done),.BC(BC));

/////////////////////////////////////////////////
// Instantiate any other units you might find //
// useful for monitoring/testing design.     //
//////////////////////////////////////////////
reg [11:0] analog_mem[0:65535];
reg [11:0] error_res;
int index;

initial
 $readmemh("analog.dat",analog_mem);
				
initial begin
  ///////////////////////////////////////////////////
  // This is main body of your test.              //
  // Keep in mind you don't have to do this as   //
  // one big super test.  It would be better to //
  // have a suite of smaller top level tests.  //
  //////////////////////////////////////////////
	initialize;

	transmitBC_checkCorrectBC;
	incorrectBCid_checkKeepMoving;
	
	check_stop_cmd;
	check_go_bypassBadBCid;
	check_correctBCid_stop;

	prox_obstruction;

	test_garbage_cmds;
	testGo_obstr_stop_noObstr;


	/// wait a little and see if fwd/rev signals are set
	checkMath;


	$display("you've reached the end");
	$stop;
 
end

always
  #1 clk = ~ clk;


//set up all the original testbench values
task initialize;
	cmd = 8'b00_000000;
	Barcode = 8'b11_111111;
	OK2Move = 1'b1;
	send_cmd = 1'b0;
	send_BC = 1'b0;
	clk = 1'b0;
	rst_n = 1'b0;
	@(posedge clk);
	@(negedge clk);
	rst_n = 1;
endtask


//send a go command with whatever 6 bit ID you want
task go_cmd;
	input [5:0] id;

	cmd = {2'b01, id};
	send_cmd = 1'b1;
	@(posedge clk);
	@(negedge clk);
	send_cmd=1'b0;
endtask


//send a stop command
task stop_cmd;
	cmd = 8'b00_000000;
	send_cmd = 1'b1;
	@(posedge clk);
	@(negedge clk);
	send_cmd = 1'b0;
endtask


//send a don't care / garbage command
task garbage_cmd;
	cmd = 8'b11_111111;
	send_cmd = 1'b1;
	@(posedge clk);
	@(negedge clk);
	send_cmd = 1'b0;
endtask


//send a barcode with whatever 6 bit ID you want
task send_barcode;
	input [5:0] id;

	Barcode = {2'b00, id};
	send_BC = 1'b1;
	@(posedge clk);
	@(negedge clk);
	send_BC = 1'b0;
endtask


/*
	-Check if barcode transmits correctly
	-Check if correct barcode makes robot stop
*/
task transmitBC_checkCorrectBC;
	go_cmd(6'b111011);

	repeat(4095*6) @(posedge clk); //wait a short while to simulate motor start-up

	send_barcode(6'b111011);
	fork
		begin: test1
			forever @(posedge clk);
		end
		begin
			@(posedge BC_done);
				disable test1;
		end		
	join
	$display("%d: barcode done transmitting", $time);
	fork
		begin: test2
			forever @(posedge clk);
		end
		begin
			if(!in_transit)
				disable test2;
		end		
	join
	$display("%d: robot found the correct barcode and stopped", $time);
	$display("%d: transmitBC_checkCorrectBC TEST PASSED", $time);
endtask


/*
	-Check if robot keeps moving with incorrect barcode
*/
task incorrectBCid_checkKeepMoving;
	go_cmd(6'b001101);

	repeat(4095*6) @(posedge clk); //wait a short while to simulate motor start-up

	send_barcode(6'b110100);
	fork
		begin: test3
			forever @(posedge clk);
		end
		begin
			@(posedge in_transit)
				disable test3;
		end		
	join
	$display("%d: kept moving past incorrect barcode", $time);
	$display("%d: incorrectBCid_checkKeepMoving TEST PASSED", $time);
endtask


/*
	-Send stop command and check if robot stops
*/
task check_stop_cmd;
	go_cmd(6'b000000);
	repeat(4095*10) @(posedge clk);
	stop_cmd;
	fork
		begin: test6
			forever @(posedge clk);
		end
		begin
			@(negedge in_transit)
				disable test6;
		end		
	join
	$display("%d: robot stopped due to stop command", $time);
	$display("%d: check_stop_cmd TEST PASSED", $time);
endtask
	


/*
	-See if robot goes again at go command, and if it
	keeps on going when a barcode w/o matching ID is sent
*/
task check_go_bypassBadBCid;
	go_cmd(6'b001101);

	repeat(4095*6) @(posedge clk); //wait a short while to simulate motor start-up

	send_barcode(6'b111011);

	fork
		begin: test8
			forever @(posedge clk);
		end
		begin
			@(posedge BC_done)
				disable test8;
		end		
	join

	$display("%d: robot bypassed incorrect barcode", $time);
	repeat(4095*6) @(posedge clk);  //wait a short while until robot gets to new barcode
	$display("%d: check_go_bypassBadBCid TEST PASSED", $time);
endtask


/*
	-See if robot stops after a barcode w/ matching ID is sent
*/
task check_correctBCid_stop;
	go_cmd(6'b001101);
	repeat(4095*5) @(posedge clk);
	send_barcode(6'b001101);
	fork
		begin: test9
			forever @(posedge clk);
		end
		begin
			@(negedge in_transit)
				disable test9;
		end		
	join

	$display("%d: robot stopped after finding the correct barcode!", $time);
	$display("%d: check_correctBCid_stop TEST PASSED", $time);
endtask


//check if robot stops when OK2Move goes low, and if robot continues moving after OK2Move goes high again
task prox_obstruction;
	go_cmd(6'b111111);
	repeat(4095*5) @(posedge clk);
	OK2Move = 1'b0;
	fork
		begin: obstruction
			forever @(posedge clk);
		end
		begin
			@(posedge buzz)//negedge iDUT.iCORE.cmd_cntrl.go) <-- might need to do something else here
				disable obstruction;
		end		
	join
	$display("%d: robot stopped at OK2Move --> 1'b0", $time);
	repeat(4095*12) @(posedge clk);
	OK2Move  = 1'b1;
	fork
		begin: clear
			forever @(posedge clk);
		end
		begin
			@(posedge fwd_lft or posedge fwd_rht)//posedge iDUT.iCORE.cmd_cntrl.go)
				disable clear;
		end		
	join
	$display("%d: robot goes again at OK2Move --> 1'b1", $time);
	$display("%d: prox_obstruction TEST PASSED", $time);
endtask


//name is self explanatory
task test_garbage_cmds;
	go_cmd(6'b101010);
	repeat(4095*2) @(posedge clk);
	garbage_cmd;
	fork
		begin
			repeat(4095*10) @(posedge clk);
			disable gbgtest1;
			$display("%d: sent a garbage command and it didn't affect anything!", $time);
		end
		begin: gbgtest1
			@(negedge in_transit) begin
				$display("%d: sent a garbage command and it changed in transit :(", $time);
				$display("%d: test_garbage_cmds TEST FAILED", $time);
				$stop;
			end
		end
	join

	stop_cmd;
	repeat(4095*2) @(posedge clk);
	garbage_cmd;
	fork
		begin
			repeat(4095*10) @(posedge clk);
			disable gbgtest2;
			$display("%d: sent a garbage command and it didn't affect anything!", $time);
		end
		begin: gbgtest2
			@(posedge in_transit) begin
				$display("%d: sent a garbage command and it changed in transit :(", $time);
				$display("%d: test_garbage_cmds TEST FAILED", $time);
				$stop;
			end
		end
	join
	$display("%d: test_garbage_cmds TEST PASSED", $time);
endtask


//test if the robot stays stopped after obstruction in the way --> stop command --> obstruction moved
task testGo_obstr_stop_noObstr;
	go_cmd(6'b111000);
	$display("%d: sent go command", $time);
	repeat(4095*2) @(posedge clk);
	OK2Move = 1'b0;
	$display("%d: OK2Move went low", $time);
	repeat(4095*2) @(posedge clk);
	stop_cmd;
	$display("%d: sent stop command", $time);
	repeat(4095*5) @(posedge clk);
	OK2Move = 1'b1;
	$display("%d: OK2Move went high", $time);
	fork
		begin
			repeat(4095*10) @(posedge clk);
			disable obs1;
			$display("%d: robot stays stopped after obstruction is removed", $time);
		end
		begin: obs1
			@(posedge in_transit) begin
				$display("%d: robot moved after obstruction is moved even though the cmd is stop :(", $time);
				$display("%d: testGo_obstr_stop_noObstr TEST FAILED", $time);
				$stop;
			end
		end
	join
	$display("%d: testGo_obstr_stop_noObstr TEST PASSED", $time);
endtask


task checkMath;
	initialize;
	go_cmd(6'b101010);
	
	for(index=0; index<60; index++)begin
		while(!iDUT.iCORE.motion_cntrl.wrt_en_Error)
			@(posedge clk);

		assign error_res = ~analog_mem[(index*48)+1]-~analog_mem[(index*48)+8]+
			(2*~analog_mem[(index*48)+20])-(2*~analog_mem[(index*48)+26])+
			(4*~analog_mem[(index*48)+35])-(4*~analog_mem[(index*48)+47]);

		@(posedge clk);
		@(negedge clk);
	
		
		 if(error_res== iDUT.iCORE.motion_cntrl.Error)
				$display("conversion one success Error=%h",iDUT.iCORE.motion_cntrl.Error);
		else
				$display("conversion one fail Error=%h expected = %h ",iDUT.iCORE.motion_cntrl.Error, error_res);

		
		while(!iDUT.iCORE.motion_cntrl.wrt_en_lft)
			@(posedge clk);

		@(posedge clk);
		@(negedge clk);
		$display("left: %h, right %h", iDUT.iCORE.motion_cntrl.lft, iDUT.iCORE.motion_cntrl.rht);
	end
endtask



endmodule
