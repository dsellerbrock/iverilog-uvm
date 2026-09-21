// Regression for factor-local negative interval proof. `gate` is selected
// state, not a rand variable: it must be substituted/retained before !factor.
class connected_state_item;
  rand bit [9:0] value;
  rand bit unrelated;
  bit gate = 1;
  constraint gate_c { gate == 1; }
  constraint dist_c { value dist {[0:300] :/ 1, [301:511] :/ 3}; }
  constraint state_c { if (gate) value inside {[0:511]}; }
  constraint independent_c { unrelated inside {0, 1}; }
endclass
module test;
  connected_state_item item;
  int low, high;
  initial begin
    item = new; item.srandom(32'hc011ec7e);
    repeat (128) begin
      if (!item.randomize()) $fatal(1, "randomize failed");
      if (item.value <= 300) low++; else high++;
    end
    if (low < 7 || low > 65) $fatal(1, "exact connected-state item sampling failed");
    $display("PASSED");
  end
endmodule
