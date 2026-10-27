module issue1221_dynamic_array_negative_size;
  int a[];
  int n;

  initial begin
    n = -1;
    a = new[n];
    $display("UNEXPECTED continuation");
  end
endmodule
