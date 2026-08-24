// IEEE 1800-2017 14.3/14.16: a selected output clockvar declared with a
// hierarchical signal alias drives that raw signal without replacing sibling
// bits and without bypassing the clocking event.
`timescale 1ns/1ps

module selected_alias_storage;
  logic [7:0] raw;
endmodule

module selected_alias_receiver(input logic clk);
  wire [7:0] bus;
  integer failures = 0;
  selected_alias_storage child();

  clocking cb @(posedge clk);
    output bus = child.raw;
  endclocking

  initial begin
    child.raw = 8'hA5;
    #2 cb.bus[3:0] <= 4'hC;
    #1;
    if (child.raw !== 8'hA5) begin
      failures++;
      $display("FAILED alias selected drive landed early raw=%h", child.raw);
    end
    #3;
    if (child.raw !== 8'hAC) begin
      failures++;
      $display("FAILED alias selected drive raw=%h expected=ac", child.raw);
    end
  end
endmodule

module sv_clocking_selected_output_alias;
  logic clk = 1'b0;
  integer failures = 0;

  always #5 clk = ~clk;

  generate
    for (genvar idx = 0; idx < 1; idx++) begin : g
      selected_alias_receiver u(clk);
    end
  endgenerate

  initial begin
    #8;
    g[0].u.cb.bus[6:5] <= 2'b11;
    #1;
    if (g[0].u.child.raw !== 8'hAC) begin
      failures++;
      $display("FAILED static alias selected drive landed early raw=%h",
               g[0].u.child.raw);
    end
    #7;
    if (g[0].u.child.raw !== 8'hEC) begin
      failures++;
      $display("FAILED static alias selected drive raw=%h expected=ec",
               g[0].u.child.raw);
    end

    failures += g[0].u.failures;
    if (failures != 0)
      $fatal(1, "%0d selected alias clocking checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
