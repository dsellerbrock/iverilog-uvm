// p84: G32 — method chain on class-handle return value
// b.with_v(10).with_v(99) — second call must use the object
// returned by the first call, not the original.
class Builder;
  int v = 0;
  function Builder with_v(int x);
    automatic Builder b = new();
    b.v = x;
    return b;
  endfunction
endclass

module top;
  initial begin
    automatic Builder b = new();
    automatic Builder r = b.with_v(10).with_v(99);
    if (r.v == 99)
      $display("PASS: method chain p84");
    else
      $display("FAIL: expected 99 got %0d", r.v);
    $finish;
  end
endmodule
