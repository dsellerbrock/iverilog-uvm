module issue1160_sscanf_binary_underscore;
  bit [4095:0] v;
  int n;

  initial begin
    n = $sscanf("1_0110", "%b", v);
    $display("%0d %b", n, v[4:0]);
  end
endmodule
