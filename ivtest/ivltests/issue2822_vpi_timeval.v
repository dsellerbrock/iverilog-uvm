module top;
  logic [63:0] v = 64'h12345678_9abcdef0;
  logic [63:0] xz = 64'h1234_xxxx_zzzz_5678;

  initial #1 begin
    $probe;
    $display("DONE");
  end
endmodule
