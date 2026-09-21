module test;
 reg clk=0;
 reg [2:0] addr=0;
 reg [1:0] mask=0;
 reg [7:0] data=0;
 reg [7:0] mem[0:2];
 always @(posedge clk) begin
   if(mask[0]) mem[addr][3:0] <= data[3:0];
   if(mask[1]) mem[addr][7:4] <= data[7:4];
 end
 task tick; #1 clk=1; #1 clk=0; endtask
 (* ivl_synthesis_off *) initial begin
   mask=3;addr=0;data=8'hab;tick();
   addr=1;data=8'hcd;tick();addr=2;data=8'hef;tick();
   addr=0;data=8'h35;mask=1;tick();
   if(mem[0]!==8'ha5 || mem[1]!==8'hcd || mem[2]!==8'hef) $fatal(1,"low mask %h %h %h",mem[0],mem[1],mem[2]);
   mask=2;tick();
   if(mem[0]!==8'h35) $fatal(1,"high mask");
   addr=1;mask=0;data=0;tick();
   if(mem[1]!==8'hcd) $fatal(1,"disabled write");
   addr=2;mask=3;data=8'h67;tick();
   if(mem[2]!==8'h67) $fatal(1,"both masks");
   addr=3;data=0;tick();addr='x;tick();addr='z;tick();
   if(mem[0]!==8'h35 || mem[1]!==8'hcd || mem[2]!==8'h67) $fatal(1,"invalid word write");
   $display("PASSED");$finish(0);
 end
endmodule
