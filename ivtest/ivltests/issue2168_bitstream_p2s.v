module issue2168_bitstream_p2s;
  typedef struct { byte a; byte b; } s_t;
  typedef bit [15:0] p16_t;
  s_t s;
  p16_t v;

  initial begin
    s = s_t'(16'h1234);
    if (s.a !== 8'h12 || s.b !== 8'h34)
      $fatal(1, "p2s produced %h %h", s.a, s.b);
    $display("PASSED");
  end
endmodule
