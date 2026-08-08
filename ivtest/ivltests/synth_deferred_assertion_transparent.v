`begin_keywords "1800-2012"

module main;
  logic a;
  logic b;
  logic y;

  // The assignment is hardware; the deferred assertion is verification-only
  // and must not make the containing combinational process unsynthesizable.
  always_comb begin
    y = a ^ b;
    proc_a: assert #0 (y == (a ^ b)) else $display("BAD_PROC");
  end

  // A module/generate assertion item creates its own implicit always_comb,
  // which must likewise disappear cleanly from a synthesized design.
  item_a: assert #0 (y == (a ^ b)) else $display("BAD_ITEM");

  (* ivl_synthesis_off *)
  initial begin
    a = 1'b0;
    b = 1'b1;
    #1;
    if (y !== 1'b1) begin
      $display("FAILED first value");
      $finish;
    end
    a = 1'b1;
    #1;
    if (y !== 1'b0) begin
      $display("FAILED second value");
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
