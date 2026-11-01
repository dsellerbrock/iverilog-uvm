class D;
  rand int v, w, x, y;
  rand bit [31:0] f;
  constraint c { y == x + 1; x == v + 100; w == x + 1; f == 7; }
endclass

module tb;
  D d;
  initial begin
    d = new;
    if (!d.randomize()) $fatal(1, "randomize failed");
    if (d.x - d.v != 100 || d.y - d.x != 1 || d.w - d.x != 1
        || d.f != 7)
      $fatal(1, "constraint mismatch");
    $display("1 %0d %0d %0d %08h", d.x - d.v, d.y - d.x,
             d.w - d.x, d.f);
  end
endmodule
