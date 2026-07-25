// edge[10] must select the falling transition; a two-entry list must
// select both. Same stimulus in all three, so the counts discriminate.
module d10(input clk, d); specify $setup(edge[10] d, posedge clk, 10); endspecify endmodule
module dbo(input clk, d); specify $setup(edge[01,10] d, posedge clk, 10); endspecify endmodule
module tb;
  reg c1=0, c2=0, d=0;
  d10 u10(c1,d);
  dbo ubo(c2,d);
  initial begin
    #10 d=1; #1 begin c1=1; c2=1; end     // 0->1 near clock
    #10 begin c1=0; c2=0; end
    #10 d=0; #1 begin c1=1; c2=1; end     // 1->0 near clock
    #10 $display("DONE: expect u10 -> one at 32; ubo -> two at 11 and 32");
    $finish(0);
  end
endmodule
