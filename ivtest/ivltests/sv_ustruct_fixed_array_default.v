module sv_ustruct_fixed_array_default;
  typedef struct { byte data[2] = '{2{1}}; } pkt_t;
  pkt_t p;
  initial begin
    if (p.data[0] !== 1 || p.data[1] !== 1)
      $fatal(1, "fixed array member default: %0d %0d", p.data[0], p.data[1]);
    $display("PASSED");
    $finish(0);
  end
endmodule
