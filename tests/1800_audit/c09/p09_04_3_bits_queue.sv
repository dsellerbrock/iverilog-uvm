module top;
  byte stream[$];
  int n;
  bit hit;
  initial begin
    n = $bits(stream);
    $display("INFO bits_empty=%0d", n);
    repeat (8) stream.push_back(1);
    n = $bits(stream);
    $display("INFO bits_8_bytes=%0d (expect 64)", n);
    fork wait (n > 60); join_none
    #1 $display("PASS wait_runtime_var");
    $finish;
  end
endmodule
