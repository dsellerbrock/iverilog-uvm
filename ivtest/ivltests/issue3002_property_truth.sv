module issue3002_property_truth;
  bit clk = 0;
  logic [1:0] a, b;
  logic [1:0] values [0:5];
  integer ip = 0, ifail = 0, ep = 0, efail = 0;
  integer want_ip = 0, want_ifail = 0, want_ep = 0, want_efail = 0;
  integer i, j;
  bit at, bt;

  always #5 clk = ~clk;
  assert property (@(posedge clk) (a) implies (b)) ip++; else ifail++;
  assert property (@(posedge clk) (a) iff (b)) ep++; else efail++;

  initial begin
    values[0] = 2'b00; values[1] = 2'b01;
    values[2] = 2'b0x; values[3] = 2'b0z;
    values[4] = 2'b1x; values[5] = 2'b1z;
    for (i = 0; i < 6; i++) begin
      for (j = 0; j < 6; j++) begin
        a = values[i]; b = values[j];
        at = (i == 1 || i >= 4); bt = (j == 1 || j >= 4);
        if (!at || bt) want_ip++; else want_ifail++;
        if (at == bt) want_ep++; else want_efail++;
        @(posedge clk); #1;
        if (ip != want_ip || ifail != want_ifail ||
            ep != want_ep || efail != want_efail)
          $fatal(1, "a=%b b=%b implies=%0d/%0d expected=%0d/%0d iff=%0d/%0d expected=%0d/%0d",
                 a, b, ip, ifail, want_ip, want_ifail,
                 ep, efail, want_ep, want_efail);
        @(negedge clk);
      end
    end
    $display("PASS property truth");
    $finish(0);
  end
endmodule
