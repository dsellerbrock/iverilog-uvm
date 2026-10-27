class cov_item;
  bit val;
  covergroup cg;
    cp: coverpoint val {
      bins zero = {0};
      bins one = {1};
    }
  endgroup

  function new();
    cg = new();
  endfunction

  function void sample_zero();
    val = 0;
    cg.sample();
  endfunction
endclass

module p20_14_cov;
  localparam int SV_COV_CHECK = 3;
  localparam int SV_COV_MODULE = 10;
  localparam int SV_COV_TOGGLE = 23;
  localparam int SV_COV_NOCOV = 0;

  cov_item item;
  int r1, r2, r3;

  initial begin
    item = new();
    item.sample_zero();
    r1 = $coverage_control(SV_COV_CHECK, SV_COV_TOGGLE, SV_COV_MODULE, "p20_14_cov");
    r2 = $coverage_get_max(SV_COV_TOGGLE, SV_COV_MODULE, "p20_14_cov");
    r3 = $coverage_get(SV_COV_TOGGLE, SV_COV_MODULE, "p20_14_cov");
    $display("R1 %0d", r1);
    $display("R2 %0d", r2);
    $display("R3 %0d", r3);
    $display("GC %0.2f", $get_coverage());
    $finish;
  end
endmodule
