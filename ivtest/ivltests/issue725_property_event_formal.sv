// IEEE 1800-2017/2023 16.12.18: an `event' formal of a property takes an
// event expression actual or default (posedge, negedge, edge, with an
// optional iff), which becomes the clocking event of the property body.
module t;
  logic clk = 0, a = 1, en = 1;
  always #5 clk = ~clk;
  int np = 0, nn = 0, nq = 0, ni = 0;
  time tp = 0, tn = 0, tq = 0, ti = 0;
  property p(event ev); @(ev) a; endproperty
  property q(event ev = posedge clk); @(ev) a |-> ##1 a; endproperty
  property r(event ev, logic x); @(ev) x; endproperty
  ap: assert property (p(posedge clk)) begin np++; if (!tp) tp = $time; end
      else $display("FAIL p");
  an: assert property (p(negedge clk)) begin nn++; if (!tn) tn = $time; end
      else $display("FAIL n");
  aq: assert property (q()) begin nq++; if (!tq) tq = $time; end
      else $display("FAIL q");
  ai: assert property (r(posedge clk iff en, a)) begin ni++; if (!ti) ti = $time; end
      else $display("FAIL i");
  initial begin
    #42 $display("p=%0d@%0t n=%0d@%0t q=%0d@%0t i=%0d@%0t", np, tp, nn, tn, nq, tq, ni, ti);
    if (np == 4 && tp == 5 && nn == 4 && tn == 10 && nq == 3 && tq == 15
        && ni == 4 && ti == 5) $display("PASSED");
    else $display("FAILED");
    $finish;
  end
endmodule
