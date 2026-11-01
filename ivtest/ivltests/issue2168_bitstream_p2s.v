module issue2168_bitstream_p2s;
  typedef struct { byte a; byte b; } s_t;
  typedef bit [15:0] p16_t;
  s_t s;
  p16_t v;

  initial begin
    s = s_t'(16'h1234);
    $display("p2s %h %h (expect 12 34)", s.a, s.b);
  end
endmodule
