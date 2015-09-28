module reset_synch(rst_n, RST_n, clk);

   // declare input, output signals
   input RST_n, clk;  
   output reg rst_n; 

   // internal register
   reg q;
   
   // double flops RST_n to produce rst_n
   always @(negedge clk, negedge RST_n)begin
           
          if(!RST_n)begin
            q<=0;
            rst_n<=0;
          end  
          else begin
            q<=1;
            rst_n<=q;
          end  
   end        
endmodule              