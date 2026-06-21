// Regression: foreach and the `inside` operator over a queue/darray PROPERTY
// reached through an ASSOCIATIVE-ARRAY ELEMENT, e.g.
//   foreach (cfg.ral_models[name].csr_addrs[i]) ...
//   if (addr inside {cfg.ral_models[name].csr_addrs}) ...
//
// This is the OpenTitan cip_base_scoreboard pattern (cfg.ral_models[ral_name]
// is the universal access). Before the fix:
//   - foreach over arr[expr].member[i] was an unimplemented parser stub: the
//     body was discarded -> 0 iterations (despite a correct .size()).
//   - `x inside {expr}` only treated a plain NetESignal as an array, so a
//     queue PROPERTY fell through to a scalar `x == queue` comparison -> 0.
// Both reported size() correctly, which masked the bug.

class reg_block;
  int   csr_addrs[$];    // queue property
  int   da[];            // dynamic-array property
  function void build();
    csr_addrs.delete();
    for (int i = 0; i < 13; i++) csr_addrs.push_back(i*4);
    da = new[3];
    da[0] = 100; da[1] = 200; da[2] = 300;
  endfunction
endclass

class cfg_c;
  reg_block ral_models[string];
endclass

module top;
  initial begin
    cfg_c cfg = new();
    reg_block rb = new();
    int errors = 0;
    int cnt;
    rb.build();
    cfg.ral_models["uart"] = rb;

    // foreach over the queue property via the assoc element
    cnt = 0;
    foreach (cfg.ral_models["uart"].csr_addrs[i]) cnt++;
    if (cnt != 13) begin $display("FAIL: queue foreach=%0d (expect 13)", cnt); errors++; end

    // foreach over the darray property via the assoc element
    cnt = 0;
    foreach (cfg.ral_models["uart"].da[i]) cnt++;
    if (cnt != 3) begin $display("FAIL: darray foreach=%0d (expect 3)", cnt); errors++; end

    // inside over the queue property via the assoc element
    if (!(8 inside {cfg.ral_models["uart"].csr_addrs})) begin
      $display("FAIL: 8 inside queue (expected present)"); errors++;
    end
    if (9 inside {cfg.ral_models["uart"].csr_addrs}) begin
      $display("FAIL: 9 inside queue (expected absent)"); errors++;
    end

    // inside over the darray property via the assoc element
    if (!(200 inside {cfg.ral_models["uart"].da})) begin
      $display("FAIL: 200 inside darray (expected present)"); errors++;
    end
    if (201 inside {cfg.ral_models["uart"].da}) begin
      $display("FAIL: 201 inside darray (expected absent)"); errors++;
    end

    if (errors == 0) $display("PASS");
    else $display("foreach_inside_assoc_elem_queue_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule
