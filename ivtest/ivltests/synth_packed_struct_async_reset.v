`begin_keywords "1800-2012"

module main;
  typedef struct packed {
    logic clk;
    logic reset_n;
    logic data;
  } controls_t;

  typedef struct packed {
    controls_t controls;
  } hwif_t;

  logic q;
  hwif_t hwif;

  // Generated Caliptra register files can carry clock, reset, and data through
  // sibling fields of one nested packed structure. Event probes, reset
  // predicates, and data reads must retain their exact source bit ranges;
  // widening the data read to the whole carrier hides the real clock.
  always_ff @(posedge hwif.controls.clk or
              negedge hwif.controls.reset_n) begin
    if (~hwif.controls.reset_n)
      q <= 1'b0;
    else
      q <= hwif.controls.data;
  end

  (* ivl_synthesis_off *)
  initial begin
    hwif.controls.clk = 1'b0;
    hwif.controls.data = 1'b0;
    hwif.controls.reset_n = 1'b1;

    #1 hwif.controls.data = 1'b1;
    hwif.controls.clk = 1'b1;
    #1 hwif.controls.clk = 1'b0;
    if (q !== 1'b1)
      $fatal(1, "clocked data path failed: %b", q);

    hwif.controls.reset_n = 1'b0;
    #1;
    if (q !== 1'b0)
      $fatal(1, "packed-member asynchronous reset failed: %b", q);

    hwif.controls.reset_n = 1'b1;
    hwif.controls.data = 1'b0;
    #1 hwif.controls.clk = 1'b1;
    #1 hwif.controls.clk = 1'b0;
    if (q !== 1'b0)
      $fatal(1, "post-reset data path failed: %b", q);

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
