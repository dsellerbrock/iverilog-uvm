// IEEE 1800-2017/2023 §18.14.1: appending a static process preserves
// the random streams of existing static processes.
module test;
  int unsigned first, second;

  initial begin
    first = $urandom();
    $display("first=%0d", first);
  end
  initial begin
    second = $urandom();
    $display("second=%0d", second);
  end
  initial begin
    #1;
    $display("PASS initialization RNG stability");
    $finish;
  end

`ifdef ADD_EXTRA
  initial begin
    int unsigned ignored;
    ignored = $urandom();
  end
`endif
endmodule
