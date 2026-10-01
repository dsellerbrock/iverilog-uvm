// A dynamic foreach uses an internal size pass and element pass, but those
// passes must consume one logical object-RNG stream.  This seed's expected
// state follows 35 authoritative-pass words: one randc prefill, one feasible
// tag choice, one size target, sixteen element-objective bits, and sixteen
// container-fill bits.
class randc_txn_rng_order_item;
  randc bit [1:0] tag;
  rand bit [7:0] data[];

  constraint tag_c { tag inside {2'd0, 2'd1, 2'd2}; }
  constraint size_c { data.size() == 2; }
  constraint iter_c { foreach (data[i]) data[i] == i + 1; }

endclass

module test;
  initial begin
    randc_txn_rng_order_item iter_item;
    string iter_state;

    iter_item = new;
    iter_item.data = new[2];
    iter_item.data[0] = 0;
    iter_item.data[1] = 0;

    iter_item.srandom(32'h51a7_20f1);

    if (iter_item.randomize() !== 1)
      $fatal(1, "dynamic-array randomize failed");
    if (!(iter_item.tag inside {2'd0, 2'd1, 2'd2})
        || iter_item.data.size() != 2
        || iter_item.data[0] !== 1 || iter_item.data[1] !== 2)
      $fatal(1, "dynamic foreach constraints were not satisfied");

    // This seed's object RNG state after the 35 authoritative-pass words.
    // $urandom advances the process RNG, so it cannot be the control here.
    iter_state = iter_item.get_randstate();
    if (iter_state != "ivl1:d4504ea3e6a25808")
      $fatal(1, "two-pass solve consumed a different object RNG stream");

    $display("PASSED");
  end
endmodule
