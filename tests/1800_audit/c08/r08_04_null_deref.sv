module top;
  class Obj; int v; virtual function int f(); return 1; endfunction endclass
  Obj h; int x;
  initial begin
    $display("BEFORE");
    x = h.v;   $display("AFTER_PROP x=%0d", x);
    x = h.f(); $display("AFTER_VMETHOD x=%0d", x);
  end
endmodule
