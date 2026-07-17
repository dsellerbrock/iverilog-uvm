// Regression: a continuous assignment reading a never-written word of a
// variable (reg) array must see the word's initial value (x for 4-state),
// not z. The vvp .array/port label was resolved eagerly inside
// vpip_make_array — before the caller allocated the word storage — so
// array_attach_port found no storage and silently skipped scheduling the
// initial-value propagation; the driven net kept its z default
// (pr1648365 / pr2974294). The resolve now happens after storage is
// allocated in each compile_*_array variant.
module top;
  reg  [7:0] mem  [0:3];       // never written: words are x
  wire [7:0] w4   = mem[0];    // 4-state word through cont-assign -> xx

  reg  [7:0] mem2 [0:3];
  wire [7:0] w4b  = mem2[2];
  initial mem2[2] = 8'h5a;     // written at t0: value must propagate

  initial begin
    #1;
    if (w4 !== 8'hxx)
      $display("FAIL: unwritten word reads %h, expected xx", w4);
    else if (w4b !== 8'h5a)
      $display("FAIL: written word reads %h, expected 5a", w4b);
    else
      $display("PASS: array-word initial value propagates (x, not z)");
    $finish;
  end
endmodule
