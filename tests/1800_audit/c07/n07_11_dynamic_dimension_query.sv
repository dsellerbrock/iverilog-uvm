module n07_11_dynamic_dimension_query;
  int a[3][][5];
  initial begin
    a[2] = new[4];
    $display("%0d", $size(a,2));
  end
endmodule
