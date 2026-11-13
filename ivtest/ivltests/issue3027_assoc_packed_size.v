typedef bit [15:0] word_t;
module issue3027_assoc_packed_size;
  bit [7:0] a[int];
  word_t x;
  initial begin
    a[1] = 8'h12;
    x = word_t'(a);
    $display("FAIL: size mismatch accepted %h", x);
  end
endmodule
