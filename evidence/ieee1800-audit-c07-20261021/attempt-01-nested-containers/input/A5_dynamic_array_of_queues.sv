module tb;
  int d[][$];
  initial begin
    d = new[2];
    d[1].push_back(4);
    $display("A5 %0d %0d %0d", d.size(), d[0].size(), d[1][0]);
  end
endmodule
