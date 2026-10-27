module test;
  class Base;
    int value;
    function new(int value);
      this.value = value;
    endfunction
  endclass

  class Derived extends Base(1);
    function new();
      super.new(2);
    endfunction
  endclass

  initial begin
    Derived item;
    item = new;
    $display("value=%0d", item.value);
  end
endmodule
