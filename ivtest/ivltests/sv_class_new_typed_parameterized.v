package typed_parameterized_new_pkg;
  class parent;
    int value;

    function new(int value = 0);
      this.value = value;
    endfunction
  endclass

  class child #(int OFFSET = 1) extends parent;
    function new(int value = 0);
      super.new(value + OFFSET);
    endfunction
  endclass
endpackage

module test;
  import typed_parameterized_new_pkg::*;
  parent a;
  parent b;

  initial begin
    a = child#(.OFFSET(3))::new(.value(41));
    b = typed_parameterized_new_pkg::child#(5)::new(7);
    if (a.value != 44 || b.value != 12)
      $fatal(1, "typed parameterized constructor mismatch: %0d %0d",
             a.value, b.value);
    $display("PASSED");
  end
endmodule
