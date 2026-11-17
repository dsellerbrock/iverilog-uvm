module tb;
  int a[string];
  int q[$];
  initial begin
    a = '{default:42};
    q = {};
    if (a["x"] != 42 || q.size() != 0) $fatal(1, "bad value");
    $display("PASS");
  end
endmodule
