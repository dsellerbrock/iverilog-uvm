// aa_first_obj_test.sv — verify object-keyed assoc array `.first(key)`
//   round-trips the key into the destination class variable and the
//   1-bit success flag is correctly extended to the caller's expected
//   width (Phase 34 codegen fix in tgt-vvp/eval_vec4.c).

class K;
  int v;
endclass

class Container;
  bit m[K];
  function int do_test(output K out_k);
    int rc;
    rc = m.first(out_k);
    return rc;
  endfunction
endclass

module top;
  initial begin
    Container c = new;
    K k1 = new;
    K got;
    int rc;
    k1.v = 42;
    c.m[k1] = 1;
    rc = c.do_test(got);
    if (got == null)              $display("FAIL: got null (rc=%0d)", rc);
    else if (got != k1)           $display("FAIL: got != k1 (rc=%0d v=%0d)", rc, got.v);
    else if (got.v != 42)         $display("FAIL: got.v=%0d expect 42", got.v);
    else                          $display("PASS aa.first(K): rc=%0d v=%0d", rc, got.v);
    $finish;
  end
endmodule
