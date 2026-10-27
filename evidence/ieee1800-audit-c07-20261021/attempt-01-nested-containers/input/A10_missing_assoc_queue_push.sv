module tb;
  int m[string][$];
  initial begin
    m["a"].push_back(1);
    m["a"].push_back(2);
    m["b"].push_back(3);
    if (!m.exists("z")) m["z"].push_back(7);
    $display("A10 %0d %0d", m.num(), m["z"][0]);
  end
endmodule
