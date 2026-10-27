class P #(type T1 = logic);
  typedef T1 [1:0] T2;
endclass

module p08_23_scope_type_s4;
  function automatic P#(bit)::T2 f1();
    return 2'b10;
  endfunction
  initial $display("S4 %0d", f1());
endmodule
