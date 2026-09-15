class box;
  logic [7:0] values[1:0];
endclass
module sv_class_array_packed_incdec_context;
  box b; logic [127:0] wi, pi; logic signed [127:0] spi; logic narrow; logic [15:0] wide;
  initial begin
    b=new; b.values='{8'ha5,8'h5a}; wi='0; wi[100]=1; pi=0;
    narrow=b.values[wi][pi]++;
    if(narrow!==1'bx || b.values[1]!==8'ha5 || b.values[0]!==8'h5a)
      $fatal(1,"wide word index truncated");
    wi=1; pi='0; pi[100]=1; narrow=b.values[wi][pi]++;
    if(narrow!==1'bx || b.values[1]!==8'ha5) $fatal(1,"wide packed index truncated");
    spi=-128'sd1; narrow=b.values[1][spi]--;
    if(narrow!==1'bx || b.values[1]!==8'ha5) $fatal(1,"signed negative index changed property");
    wide=b.values[1][3:0]++;
    if(wide!==16'h0005 || b.values[1]!==8'ha6) $fatal(1,"wide result context");
    narrow=b.values[0][3:0]--;
    if(narrow!==1'b0 || b.values[0]!==8'h59) $fatal(1,"narrow result context");
    $display("PASSED");
  end
endmodule
