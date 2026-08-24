// A selected clockvar drive through a nested virtual-interface handle keeps
// the defining alias, bound instance, merge mask, event, and output skew.
`timescale 1ns/1ps

interface complex_alias_if(input logic clk);
  generate
    if (1) begin : child
      logic [7:0] raw;
    end
  endgenerate
  wire [7:0] bus;

  clocking cb @(posedge clk);
    output #1 bus = child.raw;
  endclocking
endinterface

class complex_alias_cfg;
  virtual complex_alias_if vif;
endclass

module sv_vif_clocking_output_complex_alias;
  logic clk = 1'b0;
  complex_alias_if a(clk);
  complex_alias_if b(clk);
  complex_alias_cfg cfg;
  integer failures = 0;

  always #5 clk = ~clk;

  task check(input logic [7:0] expected_a,
             input logic [7:0] expected_b,
             input string label_text);
    if (a.child.raw !== expected_a || b.child.raw !== expected_b) begin
      failures++;
      $display("FAILED %s at %0t a=%h b=%h expected=%h/%h",
               label_text, $time, a.child.raw, b.child.raw,
               expected_a, expected_b);
    end
  endtask

  initial begin
    cfg = new;
    cfg.vif = a;
    a.child.raw = 8'hA5;
    b.child.raw = 8'h3C;

    // Buffered before the edge: preserve the unselected high nibble.
    #1 cfg.vif.cb.bus[3:0] <= 4'h2;
    #4 check(8'hA5, 8'h3C, "buffered drive at event");
    #999ps check(8'hA5, 8'h3C, "buffered drive before skew");
    #2ps check(8'hA2, 8'h3C, "buffered selected merge");

    // Issued in the current clocking event: preserve the low nibble.
    @(cfg.vif.cb);
    cfg.vif.cb.bus[7:4] <= 4'hC;
    #999ps check(8'hA2, 8'h3C, "current drive before skew");
    #2ps check(8'hC2, 8'h3C, "current selected merge");

    // Repeat the same clockvar value after a direct destination alteration.
    @(cfg.vif.cb);
    a.child.raw[7:4] = 4'h3;
    cfg.vif.cb.bus[7:4] <= 4'hC;
    #999ps check(8'h32, 8'h3C, "repeat drive before skew");
    #2ps check(8'hC2, 8'h3C, "repeat same-value current drive");

    if (failures != 0)
      $fatal(1, "%0d complex alias checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
