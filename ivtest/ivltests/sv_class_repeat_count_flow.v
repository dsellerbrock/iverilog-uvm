// IEEE 1800-2017/2023 8.19 and 19.5: literal repeat counts participate in
// constructor-order flow with their expression width and signedness intact.
module top;
  class negative_repeat_c;
    const int limit;
    covergroup cg with function sample(int value);
      cp: coverpoint value {
        bins in_range = {[0:limit]};
      }
    endgroup
    function new(int v);
      // The negative count executes zero times, so this constructor call is
      // unreachable and cannot precede the initializer below.
      repeat (-1)
        cg = new;
      limit = v;
      cg = new;
    endfunction
  endclass

  class width_preserving_negate_c;
    const int limit;
    covergroup cg with function sample(int value);
      cp: coverpoint value {
        bins in_range = {[0:limit]};
      }
    endgroup
    function new(int v);
      // Unary minus preserves the 32-bit unsigned width: this is 32'h1 and
      // therefore executes exactly once.
      repeat (-32'hffff_ffff)
        limit = v;
      cg = new;
    endfunction
  endclass

  negative_repeat_c negative_object;
  width_preserving_negate_c wrapped_object;
  initial begin
    negative_object = new(12);
    wrapped_object = new(13);
    if (negative_object.limit !== 12 || wrapped_object.limit !== 13)
      $fatal(1, "repeat-count flow mismatch");
    $display("PASSED");
  end
endmodule
