module test;
  logic [3:0] v;
  covergroup cg;
    cp: coverpoint v {
      bins valid[] = {1, 2};
      illegal_bins invalid = {15};
    }
  endgroup
  cg cov = new();
  initial begin
    v = 1; cov.sample();
    $display("BEFORE_ILLEGAL_SAMPLE");
    v = 15; cov.sample();
    $display("AFTER_ILLEGAL_SAMPLE");
    $finish;
  end
endmodule
