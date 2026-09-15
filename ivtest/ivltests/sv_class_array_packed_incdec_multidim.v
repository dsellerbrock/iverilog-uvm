class box;
  logic [15:8] values[-1:0][3:2];
endclass
module sv_class_array_packed_incdec_multidim;
  box b; logic [3:0] post; logic pre;
  initial begin
    b=new;
    b.values[-1][3]=8'ha5; b.values[-1][2]=8'h5a;
    b.values[0][3]=8'hc3; b.values[0][2]=8'h3c;
    post=b.values[-1][2][11:8]++;
    pre=++b.values[0][3][15];
    if(post!==4'ha || pre!==1'b0 || b.values[-1][2]!==8'h5b ||
       b.values[-1][3]!==8'ha5 || b.values[0][3]!==8'h43 ||
       b.values[0][2]!==8'h3c)
      $fatal(1,"multidimensional property neighbors or result wrong");
    $display("PASSED");
  end
endmodule
