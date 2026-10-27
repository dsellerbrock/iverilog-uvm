class C;
  protected int value = 0;
endclass
module top;
  C c;
  initial begin
    c = new;
    c.value = 1;
    $display("outside write=%0d", c.value);
  end
endmodule
