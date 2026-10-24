module p07_11_query_var_dimension;
  int a[3][][5];
  initial begin
    a[2] = new[4];
    $display("M %0d %0d %0d %0d %0d", $unpacked_dimensions(a), $size(a,1), $size(a[2],1), $size(a[1],1), $size(a,3));
  end
endmodule
