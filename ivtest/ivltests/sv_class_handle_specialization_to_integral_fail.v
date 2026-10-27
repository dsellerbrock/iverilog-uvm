module sv_class_handle_specialization_to_integral_fail;
  class payload; endclass

  class box #(type T = int);
    T item;
    function void f();
      logic q;
      q = item;
    endfunction
  endclass

  box#(payload) b;
  initial b.f();
endmodule
