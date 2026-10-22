module tb;
  int m[string][$];
  initial begin
    m["a"].push_back(1);
    m["a"].push_back(2);
    m["b"].push_back(3);
    $display("A1 %0d %0d %0d %0d", m.num(), m["a"].size(), m["a"][1], m["b"][0]);
  end
endmodule
