class C;
  protected int value = 0;
  protected function new(); endfunction
  protected function int read_value(); return value; endfunction
endclass
module top;
  C c;
  initial begin
    c = new;
    c.value = 1;
    $display("outside read=%0d", c.value);
    $display("outside method=%0d", c.read_value());
  end
endmodule
