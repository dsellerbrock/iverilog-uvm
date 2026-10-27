class B;
  protected int value = 0;
endclass
class D extends B;
  function void set_value(int v); value = v; endfunction
  function int get_value(); return value; endfunction
endclass
module top;
  D d;
  initial begin
    d = new;
    d.set_value(2);
    $display("subclass access=%0d", d.get_value());
  end
endmodule
