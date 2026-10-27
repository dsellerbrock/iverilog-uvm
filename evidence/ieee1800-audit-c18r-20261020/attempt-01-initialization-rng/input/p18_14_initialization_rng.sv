// IEEE 1800-2017/2023 §18.14.1: adding a static process last preserves
// the random streams of the existing static processes in the same instance.
module init_rng_case #(parameter bit EXTRA = 0)(
  output int unsigned first,
  output int unsigned second
);
  initial first = $urandom();
  initial second = $urandom();

  if (EXTRA) begin : g_extra
    initial begin
      int unsigned ignored;
      ignored = $urandom();
    end
  end
endmodule

module test;
  int unsigned base_first, base_second;
  int unsigned extra_first, extra_second;

  init_rng_case #(.EXTRA(0)) base (base_first, base_second);
  init_rng_case #(.EXTRA(1)) with_extra (extra_first, extra_second);

  initial begin
    #1;
    if (base_first !== extra_first || base_second !== extra_second)
      $fatal(1, "adding a later static process changed prior RNG streams");
    $display("PASS initialization RNG stability");
    $finish;
  end
endmodule
