module sv_interface_class_nested_interface_fail_2017;
  interface class Outer;
    interface class Nested;
      pure virtual function void f();
    endclass
  endclass
endmodule
