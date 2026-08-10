// A class shallow copy carries instance rand_mode, constraint_mode, and randc
// cyclic state.  It does not duplicate canonical static state.  Rewinding both
// object RNGs to the original's pre-first-call state makes missing copied
// history observable on the very next call without a statistical oracle.
class randc_txn_copy_item;
  randc bit [1:0] value;
  constraint harmless_c { 1'b1; }
endclass

module test;
  initial begin
    randc_txn_copy_item original;
    randc_txn_copy_item copied;
    string state_before_first;
    bit [1:0] first_value;

    original = new;
    original.srandom(32'hdead_beef);
    state_before_first = original.get_randstate();
    if (original.randomize() !== 1)
      $fatal(1, "original first randomize failed");
    first_value = original.value;

    original.value.rand_mode(0);
    original.harmless_c.constraint_mode(0);
    copied = new original;
    if (copied.value.rand_mode() !== 0)
      $fatal(1, "shallow copy did not copy rand_mode");
    if (copied.harmless_c.constraint_mode() !== 0)
      $fatal(1, "shallow copy did not copy constraint_mode");

    original.value.rand_mode(1);
    copied.value.rand_mode(1);
    original.set_randstate(state_before_first);
    copied.set_randstate(state_before_first);
    if (original.randomize() !== 1 || copied.randomize() !== 1)
      $fatal(1, "post-copy history comparison randomize failed");
    if (original.value !== copied.value)
      $fatal(1, "shallow copy did not copy randc cyclic state");
    if (original.value === first_value || copied.value === first_value)
      $fatal(1, "copied randc history allowed the already-used value");

    $display("PASSED");
  end
endmodule
