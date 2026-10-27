class P #(type T1 = logic);
  typedef T1 [1:0] T2;
endclass

module p08_23_scope_type_s1;
  P#(bit)::T2 v1;
  initial begin
    v1 = 2'b11;
    $display("S1 %0d %0d", $bits(v1), v1);
  end
endmodule
