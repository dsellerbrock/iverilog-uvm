module sv_type_operator_cast;
  int i = 1;
  logic [15:0] v = 16'habcd;
  int e;

  initial begin
    e = type(i + 3)'(v[15:0]);
    if (e !== 32'h0000abcd)
      $fatal(1, "type() cast produced %h", e);
    $display("PASSED");
  end
endmodule
