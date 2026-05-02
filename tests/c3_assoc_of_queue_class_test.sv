// Phase 62 / C3: assoc-array whose VALUE is a typedef'd queue of class
// handles must round-trip class handles through the assoc.
//
// Two bugs combined:
//   1. tgt-vvp/vvp_scope.c queue_kind switch did not handle nested
//      QUEUE/DARRAY in element_type — so the assoc map was emitted as
//      `Mv` (vec4-valued) instead of `Mo` (object-valued).
//   2. elaborate.cc PAssign::elaborate's netdarray/netuarray branches
//      stripped element_type a second time when lv->word() was set,
//      double-unwrapping the assoc layer.  net_assign.cc's
//      NetAssign_::net_type() already accounts for word_, so the inner
//      strip turned `assoc[K] = inner_queue` into a `K = inner_queue`
//      cast and netmisc.cc's class-cast fallback degraded the rval
//      expression to NetENull.
//
// Together: pre-fix `pool[0] = local_q` silently null'd out pool[0].
// Post-fix it round-trips queue contents.
`timescale 1ns/1ps

class K;
  int data;
  function new(int d); data = d; endfunction
endclass

typedef K kq_t[$];

module top;
  kq_t pool[int];
  initial begin
    K k0, k1, got;
    kq_t local_q, ret_q;

    k0 = new(100);
    k1 = new(200);
    local_q.push_back(k0);
    local_q.push_back(k1);

    pool[0] = local_q;
    if (!pool.exists(0))
      $fatal(1, "FAIL: pool[0] missing after assignment of queue value");

    ret_q = pool[0];
    if (ret_q.size() != 2)
      $fatal(1, "FAIL: ret_q.size() = %0d (expected 2 — assoc lost queue contents)", ret_q.size());
    got = ret_q[0];
    if (got == null)
      $fatal(1, "FAIL: ret_q[0] is null (assoc-of-queue stored as Mv lost handle)");
    if (got.data != 100)
      $fatal(1, "FAIL: ret_q[0].data = %0d (expected 100)", got.data);
    got = ret_q[1];
    if (got.data != 200)
      $fatal(1, "FAIL: ret_q[1].data = %0d (expected 200)", got.data);

    $display("PASS: assoc[int] of queue-of-class round-trips correctly");
    $finish;
  end
endmodule
