// A hierarchical name whose EARLIER component carries a constant index:
// an array of instances, foreach over an array inside one of them.
module sub;
  logic [3:0] bus [0:2];
endmodule
module top;
  sub u[0:1]();
  int n_inst_idx = 0, n_plain = 0;
  sub w();
  initial begin
    foreach (w.bus[i])    n_plain++;      // hierarchical, no instance index
    foreach (u[1].bus[i]) n_inst_idx++;   // hierarchical + constant instance index
    $display("plain hier=%0d (want 3)   indexed instance=%0d (want 3)",
             n_plain, n_inst_idx);
    $finish(0);
  end
endmodule
