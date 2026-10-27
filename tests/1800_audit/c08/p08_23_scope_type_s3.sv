interface class IA #(type T1 = logic);
  typedef T1 [1:0] T2;
  pure virtual function T2 fa();
endclass

interface class IB #(type T = bit) extends IA #(T);
  pure virtual function T2 fb();
endclass

module p08_23_scope_type_s3;
  IB#(bit)::T2 v3;
  initial begin
    v3 = 2'b01;
    $display("S3 %0d %0d", $bits(v3), v3);
  end
endmodule
