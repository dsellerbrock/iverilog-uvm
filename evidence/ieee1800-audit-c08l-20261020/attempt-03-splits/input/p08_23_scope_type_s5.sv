interface class IA #(type T1 = logic);
  typedef T1 [1:0] T2;
  pure virtual function T2 fa();
endclass

interface class IB #(type T = bit) extends IA #(T);
  pure virtual function T2 fb();
endclass

module p08_23_scope_type_s5;
  function automatic IB#(bit)::T2 f2();
    return 2'b01;
  endfunction
  initial $display("S5 %0d", f2());
endmodule
