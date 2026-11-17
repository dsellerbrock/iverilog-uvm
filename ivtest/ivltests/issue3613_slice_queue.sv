module main;
  bit [7:0] source[2];
  bit [0:7] result[$];
  initial begin
    source[0] = 8'h12;
    source[1] = 8'ha5;
    result = source[0:1];
    if (result.size() != 2 || result[0] !== 8'h12 || result[1] !== 8'ha5)
      $fatal(1, "incorrect slice assignment");
    $display("PASS");
  end
endmodule
