// IEEE 1800-2017/2023 15.4.5-15.4.8: each mailbox retrieval method has one
// ref message argument, and that argument shall be a valid left-hand
// expression. This is also an error-recovery reducer for exact method arity.
module sv_mailbox_ref_output_fail;
  mailbox mbx;
  int a;
  int b;
  int status;

  initial begin
    mbx = new();

    // A ref output must be one writable variable expression.
    mbx.get(a + 1);
    mbx.peek({a, b});

    // Statement calls must diagnose before mapping surplus actuals.
    mbx.put(a, b);
    mbx.get(a, b);
    mbx.peek();

    // Expression calls require exactly one known, nonempty message actual.
    status = mbx.try_get();
    status = mbx.try_peek(a, b);
    status = mbx.try_get(.message());
    status = mbx.try_peek(.unknown(a));
  end
endmodule
