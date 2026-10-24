module tb;
  int m[string][$];
  initial begin
    m["a"].push_back(1);
    m["a"].push_back(2);
    m["b"].push_back(3);
    foreach (m[k, i]) $display("A3 %s%0d=%0d", k, i, m[k][i]);
  end
endmodule
