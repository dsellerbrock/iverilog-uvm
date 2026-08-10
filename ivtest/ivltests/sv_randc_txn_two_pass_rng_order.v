// A dynamic foreach uses an internal size pass and element pass, but those
// passes must consume one logical object-RNG stream.  The control object
// advances the same seeded stream by the exact authoritative-pass budget:
// one randc prefill + one feasible-tag choice + one size target + sixteen
// element-objective bits + sixteen container-fill bits = 35 words.
class randc_txn_rng_order_item;
  randc bit [1:0] tag;
  rand bit [7:0] data[];

  constraint tag_c { tag inside {2'd0, 2'd1, 2'd2}; }
  constraint size_c { data.size() == 2; }
  constraint iter_c { foreach (data[i]) data[i] == i + 1; }

  function bit [31:0] next_rng_word();
    next_rng_word = $urandom;
  endfunction
endclass

module test;
  initial begin
    randc_txn_rng_order_item iter_item;
    randc_txn_rng_order_item control_item;
    string iter_state;
    string control_state;
    bit [31:0] ignored;

    iter_item = new;
    control_item = new;
    iter_item.data = new[2];
    iter_item.data[0] = 0;
    iter_item.data[1] = 0;

    iter_item.srandom(32'h51a7_20f1);
    control_item.srandom(32'h51a7_20f1);

    if (iter_item.randomize() !== 1)
      $fatal(1, "dynamic-array randomize failed");
    if (!(iter_item.tag inside {2'd0, 2'd1, 2'd2})
        || iter_item.data.size() != 2
        || iter_item.data[0] !== 1 || iter_item.data[1] !== 2)
      $fatal(1, "dynamic foreach constraints were not satisfied");

    repeat (35)
      ignored = control_item.next_rng_word();

    iter_state = iter_item.get_randstate();
    control_state = control_item.get_randstate();
    if (iter_state != control_state)
      $fatal(1, "two-pass solve did not consume one authoritative RNG stream");

    $display("PASSED");
  end
endmodule
