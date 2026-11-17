// IEEE 1800-2017/2023 16.12.7: for |=>, "If triggered by an empty match,
// the start point of the evaluation of the consequent property_expr is its
// nearest clock tick, starting from the tick when evaluation of the
// sequence_expr begins". b[*0:1] matches empty at every attempt, so c must
// hold on the attempt's own tick; a nonempty match (b high) also needs c
// on the next tick.
//   cycle k : 0 1 2 3 4 5   (sampled at posedge 5 + 10k)
//   a       : 0 1 0 0 0 0
//   b       : 1 0 0 1 0 0
//   c       : 0 1 0 1 1 0
// single  b[*0:1] |=> c          : fails k0, k2, k5 (empty match, c low)
// nested  a |=> (b[*0:1] |=> c)  : fails k1 (inner attempt at k2, c low)
module t;
  logic clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;
  int sf = 0, nf = 0;
  time st[$];
  bit [5:0] av = 6'b000010, bv = 6'b001001, cv = 6'b011010;
  single: assert property (@(posedge clk) b[*0:1] |=> c)
          else begin sf++; st.push_back($time); end
  nested: assert property (@(posedge clk) a |=> (b[*0:1] |=> c)) else nf++;
  initial begin
    for (int k = 0; k < 6; k++) begin
      a = av[k]; b = bv[k]; c = cv[k];
      @(negedge clk);
    end
    a = 0; b = 0; c = 1;
  end
  initial begin
    #58;
    $display("single fails=%0d at %p nested fails=%0d", sf, st, nf);
    if (sf == 3 && st[0] == 5 && st[1] == 25 && st[2] == 55 && nf == 1)
      $display("PASSED");
    else $display("FAILED");
    $finish;
  end
endmodule
