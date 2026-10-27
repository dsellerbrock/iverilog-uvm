module sv_clocking_read_output;
  bit clk;
  bit q;

  clocking cb @(posedge clk);
    output q;
  endclocking

  initial begin
    bit val;
    val = cb.q;
  end
endmodule
