module sva_param_inside_property_test;
  bit clk, rst_n, req, we;
  logic [31:0] wmask;
  int passes, failures;

  always #5 clk = ~clk;

  property byte_aligned_p(wmask_byte, c, r);
    @(posedge c) disable iff (r == 0)
      req & we |-> wmask_byte inside {'0, '1};
  endproperty

  for (genvar i = 0; i < 4; i++) begin : gen_byte
    assert property (byte_aligned_p(wmask[8*i+:8], clk, rst_n))
      passes++; else failures++;
  end

  initial begin
    rst_n = 0;
    @(negedge clk);
    rst_n = 1;
    req = 1;
    we = 1;
    wmask = 32'hff00ff00;
    @(negedge clk);
    req = 0;
    we = 0;
    repeat (2) @(negedge clk);
    if (passes != 4 || failures != 0)
      $fatal(1, "parameterized inside property counters %0d/%0d",
             passes, failures);
    $display("PASS: parameterized property clones inside expressions");
    $finish;
  end
endmodule
