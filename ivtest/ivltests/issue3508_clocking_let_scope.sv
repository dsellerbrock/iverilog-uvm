module issue3508_clocking_let_scope;
  bit clk;
  clocking cb @(posedge clk);
    let local_let(bit value) = value;
  endclocking
  bit a, b;
  initial begin
    a = local_let(1'b1);
    b = cb.local_let(1'b1);
  end
endmodule
