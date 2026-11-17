// IEEE 1800-2017/2023 16.12.9: followed-by with a temporal-property
// consequent. "sequence_expr #-# property_expr is equivalent to ...
// not (sequence_expr |-> not property_expr)", #=# to the |=> form. With a
// fixed-length sequence each attempt has one end point, so the property
// must hold at the end point of a match, and a non-match fails.
//   cycle k : 0 1 2 3 4 5   (sampled at posedge 5 + 10k)
//   a       : 1 0 1 1 0 0
//   b       : 0 1 1 0 1 0
//   c       : 0 1 0 0 1 0
// ov  a #-# (b |-> c)          : pass k0,k3          fail k1,k2,k4,k5
// nov a #=# (b |-> c)          : pass k0,k2,k3       fail k1,k4,k5
// seq (a ##1 b) #-# (b |-> c)  : pass k0,k3          fail k1,k2,k4,k5
module t;
  logic clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;
  int ovp = 0, ovf = 0, nvp = 0, nvf = 0, sqp = 0, sqf = 0, exp_ = 0, exf = 0;
  bit [5:0] av = 6'b001101, bv = 6'b010110, cv = 6'b010010;
  ov:  assert property (@(posedge clk) a #-# (b |-> c)) ovp++; else ovf++;
  nov: assert property (@(posedge clk) a #=# (b |-> c)) nvp++; else nvf++;
  sq:  assert property (@(posedge clk) (a ##1 b) #-# (b |-> c)) sqp++; else sqf++;
  // The explicit equivalent of `ov', evaluated by the existing monitor.
  ex:  assert property (@(posedge clk) a and (a |-> (b |-> c))) exp_++; else exf++;
  initial begin
    for (int k = 0; k < 6; k++) begin
      a = av[k]; b = bv[k]; c = cv[k];
      @(negedge clk);
    end
    a = 0; b = 0; c = 0;
  end
  initial begin
    #58;
    $display("ov=%0d/%0d nov=%0d/%0d seq=%0d/%0d ex=%0d/%0d",
             ovp, ovf, nvp, nvf, sqp, sqf, exp_, exf);
    if (ovp == 2 && ovf == 4 && nvp == 3 && nvf == 3 && sqp == 2 && sqf == 4
        && ovp == exp_ && ovf == exf) $display("PASSED");
    else $display("FAILED");
    $finish;
  end
endmodule
