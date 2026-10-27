class P #(type T1 = logic);
  typedef T1 [1:0] T2;
endclass

interface class IA #(type T1 = logic);
  typedef T1 [1:0] T2;
  pure virtual function T2 fa();
endclass

interface class IB #(type T = bit) extends IA #(T);
  pure virtual function T2 fb();
endclass

module p08_23_scope_type;
  P#(bit)::T2 v1;
  IA#(bit)::T2 v2;
  IB#(bit)::T2 v3;

  function automatic P#(bit)::T2 f1();
    return 2'b10;
  endfunction

  function automatic IB#(bit)::T2 f2();
    return 2'b01;
  endfunction

  initial begin
    v1 = 2'b11;
    v2 = 2'b10;
    v3 = 2'b01;
    $display("S %0d %0d %0d %0d %0d %0d", $bits(v1), $bits(v2), $bits(v3), f1(), f2(), $bits(f2()));
  end
endmodule
