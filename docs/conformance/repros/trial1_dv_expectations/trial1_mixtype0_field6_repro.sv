// The actual pinned OpenTitan prim_subreg sources are supplied on the
// compiler command line. The generated trial1_reg_top.sv instantiates this
// primitive with DW=4, SwAccessRW, RESVAL=7, we=mixtype0_we (write pulse),
// wd=reg_wdata[27:24], and the matching hw2reg field6 de/d signals.
`timescale 1ns/1ps
module trial1_mixtype0_field6_repro;
  logic clk = 0;
  always #5 clk = ~clk;
  logic rst_n = 0;
  logic sw_write = 0;
  logic [3:0] sw_data = 0;
  logic hw_write = 0;
  logic [3:0] hw_data = 0;
  logic read_pulse = 0;
  logic [3:0] q;
  logic [3:0] qs;

  prim_subreg #(
    .DW(4), .SwAccess(prim_subreg_pkg::SwAccessRW),
    .RESVAL(4'h7), .Mubi(1'b0)
  ) u_field6 (
    .clk_i(clk), .rst_ni(rst_n),
    .we(sw_write), .wd(sw_data),
    .de(hw_write), .d(hw_data),
    .qe(), .q(q), .ds(), .qs(qs)
  );

  task automatic check(input logic [3:0] expected, input string label);
    if (q !== expected || qs !== expected)
      $fatal(1, "%s: q=%h qs=%h expected=%h", label, q, qs, expected);
  endtask

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1;
    #1 check(4'h7, "reset");
    // A read pulse is not wired to field6.we by the generated register top.
    @(negedge clk) read_pulse = 1;
    @(posedge clk); #1 check(4'h7, "first read");
    @(negedge clk) read_pulse = 0;
    @(posedge clk); #1 check(4'h7, "second read");

    @(negedge clk) begin sw_write = 1; sw_data = 4'h5; end
    @(posedge clk); #1 check(4'h5, "software write");
    @(negedge clk) sw_write = 0;
    @(posedge clk); #1 check(4'h5, "read after software write");

    @(negedge clk) begin hw_write = 1; hw_data = 4'ha; end
    @(posedge clk); #1 check(4'ha, "hardware write");
    @(negedge clk) hw_write = 0;
    @(posedge clk); #1 check(4'ha, "read after hardware write");

    @(negedge clk) begin
      sw_write = 1; sw_data = 4'hc;
      hw_write = 1; hw_data = 4'h3;
    end
    @(posedge clk); #1 check(4'hc, "software/hardware collision");
    $display("PASS: field6 remains RW through reads and favors software on collision");
    $finish;
  end
endmodule
