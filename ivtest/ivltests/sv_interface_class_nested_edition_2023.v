module sv_interface_class_nested_edition_2023;
  class Outer;
    interface class Nested;
      pure virtual function void f();
    endclass
  endclass

  initial $display("PASSED");
endmodule
