class Parent;
endclass

class :final Child extends Parent;
endclass

module test;
  Child child;

  initial begin
    child = new();
    $display("PASSED");
  end
endmodule
