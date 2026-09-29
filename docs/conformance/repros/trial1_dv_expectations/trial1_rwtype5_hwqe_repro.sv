`timescale 1ns/1ps
module trial1_rwtype5_hwqe_min;
  logic clk = 0;
  always #5 clk = ~clk;
  logic rst_n = 0;
  logic we = 0;
  logic de = 0;
  logic [31:0] wd = 0;
  logic [31:0] d = 0;
  logic qe;
  logic [31:0] q, ds, qs;

  prim_subreg #(
    .DW(32),
    .SwAccess(prim_subreg_pkg::SwAccessRW),
    .RESVAL(32'hbabababa)
  ) dut (
    .clk_i(clk), .rst_ni(rst_n), .we(we), .wd(wd), .de(de), .d(d),
    .qe(qe), .q(q), .ds(ds), .qs(qs)
  );

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1;
    @(negedge clk);
    de = 1;
    d = 32'h334262fe;
    #1;
    if (we !== 0 || qe !== 1) $fatal(1, "hardware write did not pulse qe");
    @(posedge clk);
    #1;
    if (q !== 32'h334262fe) $fatal(1, "hardware write did not update q");
    @(negedge clk);
    de = 0;
    #1;
    if (qe !== 0 || q !== 32'h334262fe)
      $fatal(1, "hardware write result did not hold");
    $display("PASS: hardware de pulses qe and updates q");
    $finish;
  end
endmodule
