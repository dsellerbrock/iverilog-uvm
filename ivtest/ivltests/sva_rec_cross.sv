// IEEE 1800-2023 16.12.17: two recursion chains in one assertion pool.
// Chain B (attempt 5) fails at 35 and its levels are retired; chain C
// (attempt 15) then starts its levels at 45 and 55 in freed slots, from a
// level that may hold a higher slot. c is 0 only at 55, so C's attempt fails
// exactly at 55: every level evaluates its first tick in the tick it starts.
module sva_rec_cross;
  logic clk = 0, a1 = 0, a2 = 0, b = 1, c = 1;
  always #5 clk = ~clk;
  property prop_always(p);
    p and (1'b1 |=> prop_always(p));
  endproperty
  ab: assert property (@(posedge clk)
         (a1 |-> prop_always(b)) and (a2 |-> prop_always(c)))
    else $display("%0t fail", $time);
  initial begin
    a1 = 1;           // sampled 1 at tick 5 only
    #10 a1 = 0; a2 = 1; // a2 sampled 1 at tick 15 only
    #10 a2 = 0;
    #10 b = 0;        // b sampled 0 at tick 35 only
    #10 b = 1;
    #10 c = 0;        // c sampled 0 at tick 55 only
    #10 c = 1;
    #20 $display("done");
    $finish;
  end
endmodule
