// IEEE 1800-2023 §10.9: an untyped assignment pattern needs an assignment-like
// context, and binary equality is not one. The current diagnostic wording is
// provisional; this test requires exactly one compile error, not this message.
module sv_uarray_equality_untyped_pattern_fail;
  int A[2];
  initial begin
    A = '{1,2};
    if (A == '{1,2}) $display("unexpected equality");
  end
endmodule
