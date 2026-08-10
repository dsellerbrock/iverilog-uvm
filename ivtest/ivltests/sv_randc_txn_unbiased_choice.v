// Exact Icarus-RNG oracles for unbiased constrained choice.  The tagged
// randstate representation is implementation-defined, so these constants
// deliberately pin this implementation rather than a portable SV sequence.
class randc_txn_unbiased_item;
  randc bit [1:0] value;
endclass

module test;
  initial begin
    randc_txn_unbiased_item reject_item;
    randc_txn_unbiased_item remaining_item;

    reject_item = new;
    // From this state the pre-fill draw is aa67d952, then the solver draws
    // ffffffff for a three-value feasible set.  An unbiased bounded chooser
    // rejects that sole excess word and consumes 976e5b26 next.  Modulo uses
    // ffffffff directly and stops one word early.
    reject_item.set_randstate("ivl1:49a8f7445633f156");
    if ((reject_item.randomize() with {
          value inside {2'd0, 2'd1, 2'd2};
        }) !== 1)
      $fatal(1, "three-value constrained randomize failed");
    if (reject_item.value !== 2'd0)
      $fatal(1, "unexpected rejection-sampling choice");
    if (reject_item.get_randstate() != "ivl1:97ba2ccadbf59b05")
      $fatal(1, "bounded choice used modulo instead of rejection sampling");

    remaining_item = new;
    if ((remaining_item.randomize() with { value == 2'd1; }) !== 1
        || remaining_item.value !== 2'd1)
      $fatal(1, "failed to establish first used value");
    if ((remaining_item.randomize() with { value == 2'd2; }) !== 1
        || remaining_item.value !== 2'd2)
      $fatal(1, "failed to establish second used value");

    // The pre-fill draw 8ad7e68f selects unused value 3.  The solver draw is
    // exactly 2.  Correct selection filters to available {0,3}, where index
    // 0 chooses 0.  The old start-at-2 linear probe skips used 2 and chooses
    // 3, weighting it by the used run that precedes it.
    remaining_item.set_randstate("ivl1:fd731674c3e346fb");
    if ((remaining_item.randomize() with {
          value inside {2'd0, 2'd1, 2'd2, 2'd3};
        }) !== 1)
      $fatal(1, "remaining-value constrained randomize failed");
    if (remaining_item.value !== 2'd0)
      $fatal(1, "randc choice was not uniform over the available vector");

    $display("PASSED");
  end
endmodule
