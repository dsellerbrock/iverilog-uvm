// G07: process::self() returns valid handle with RUNNING status
module top;
  initial begin
    process p;
    p = process::self();
    if (p == null) begin
      $display("FAIL: process::self() returned null");
      $finish;
    end
    if (p.status != 1) begin
      $display("FAIL: p.status=%0d expected 1 (RUNNING)", p.status);
      $finish;
    end
    $display("PASS");
    $finish;
  end
endmodule
