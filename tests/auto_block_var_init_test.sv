// Regression: an automatic variable declared with an initializer inside a
// NAMED begin/end block was silently dropped in constant-function
// evaluation. The block-entry initializer was elaborated into the block's
// activation-frame prefix (scope 0) instead of the block body (the block's
// own scope), so when constant-function evaluation walked the block
// statements in the block's context it could not resolve the assignment
// target and the automatic local kept its default value.
//
// Covers both the constant-function path (localparam) and the runtime
// reentrant path (overlapping automatic calls). Prints PASS only if all
// sub-checks hold.
module top;

  // Automatic function with an automatic local inside a named block. Used
  // in a constant (localparam) context: the `= 1` initializer must apply on
  // each evaluation.
  function automatic integer accum(input integer value);
    begin: blk
      automatic int acc = 1;
      acc = acc + value;
      return acc;
    end
  endfunction

  localparam CV1 = accum(2);   // 1 + 2 = 3
  localparam CV2 = accum(3);   // 1 + 3 = 4  (fresh acc each eval)

  // Automatic task with an automatic named-block local, called reentrantly
  // through overlapping (delayed) invocations: each call's local must
  // re-initialize independently.
  task automatic reent(input int n, output int r);
    begin: blk
      automatic int base = 100;
      base = base + n;
      #1 r = base;
    end
  endtask

  int ra, rb;

  initial begin
    bit ok = 1;

    if (CV1 !== 3) begin ok = 0; $display("FAIL const CV1=%0d exp 3", CV1); end
    if (CV2 !== 4) begin ok = 0; $display("FAIL const CV2=%0d exp 4", CV2); end

    fork reent(1, ra); reent(2, rb); join
    if (ra !== 101) begin ok = 0; $display("FAIL reentrant ra=%0d exp 101", ra); end
    if (rb !== 102) begin ok = 0; $display("FAIL reentrant rb=%0d exp 102", rb); end

    if (ok) $display("PASS: automatic named-block var init (const + reentrant)");
    $finish;
  end
endmodule
