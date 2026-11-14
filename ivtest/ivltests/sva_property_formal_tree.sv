// A named property whose formal is used inside a property operator tree
// (`and', `or', `|=>') is instantiated with its actuals (IEEE 1800-2023
// 16.12, 16.12.17's examples written without recursion). Each named form
// must report exactly what its direct expansion reports.
module sva_property_formal_tree;
  logic clk = 0, a = 1, b = 0;
  int n_direct, n_named, n_typed, n_or_direct, n_or_named;
  always #5 clk = ~clk;

  property p_and(x);
    x and (1'b1 |=> x);
  endproperty
  property p_typed(property p);
    p and (1'b1 |=> p);
  endproperty
  property p_or(x, y);
    y or (x and (1'b1 |=> x));
  endproperty

  d1: assert property (@(posedge clk) a and (1'b1 |=> a)) else n_direct++;
  n1: assert property (@(posedge clk) p_and(a)) else n_named++;
  n2: assert property (@(posedge clk) p_typed(a)) else n_typed++;
  d3: assert property (@(posedge clk) b or (a and (1'b1 |=> a))) else n_or_direct++;
  n3: assert property (@(posedge clk) p_or(a, b)) else n_or_named++;

  initial begin
    #22 a = 0;
    #20 b = 1;
    #20;
    $display("direct %0d named %0d typed %0d", n_direct, n_named, n_typed);
    $display("or direct %0d named %0d", n_or_direct, n_or_named);
    if (n_direct == n_named && n_direct == n_typed && n_or_direct == n_or_named
        && n_direct > 0 && n_or_direct > 0)
      $display("PASSED");
    else
      $display("FAILED");
    $finish(0);
  end
endmodule
