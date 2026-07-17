// M14: width-1 class property display (IEEE 1800-2017 8 / draw_vpi).
// A 1-bit bit/logic class property passed to $display took a
// pass-object-handle fast path (its width equalled the object-handle
// width) and printed garbage; the value itself was correct. Now such a
// property is evaluated to a temp. Verified via $sformatf so the test
// checks the rendered text.
module m14_class_bit_display_test_top;
  class C; bit x; logic z; bit[0:0] w; bit[7:0] wide; endclass
  int errors = 0;
  initial begin
    C c = new;
    c.x=1; c.z=1; c.w=1; c.wide=8'hA5;
    if ($sformatf("%b", c.x)    != "1")  begin $display("FAIL x");    errors++; end
    if ($sformatf("%b", c.z)    != "1")  begin $display("FAIL z");    errors++; end
    if ($sformatf("%b", c.w)    != "1")  begin $display("FAIL w");    errors++; end
    if ($sformatf("%h", c.wide) != "a5") begin $display("FAIL wide"); errors++; end
    if (errors==0) $display("PASS: m14 class bit display");
    else $display("FAIL: m14 class bit display (%0d errors)", errors);
    $finish(0);
  end
endmodule
