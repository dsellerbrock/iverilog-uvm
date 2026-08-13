// A class shallow copy carries instance rand_mode, constraint_mode, and randc
// cyclic state.  It does not duplicate canonical static state.  Rewinding both
// object RNGs to the original's pre-first-call state makes missing copied
// history observable on the very next call without a statistical oracle.
class randc_txn_copy_item;
  randc bit [1:0] value;
  rand bit [3:0] dyn[];
  rand bit [3:0] queue_values[$];
  rand bit [3:0] assoc_values[int];
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
    original.dyn = new[3];
    original.queue_values = '{1, 2};
    original.assoc_values[4] = 4;
    original.assoc_values[9] = 9;
    state_before_first = original.get_randstate();
    if (original.randomize() !== 1)
      $fatal(1, "original first randomize failed");
    first_value = original.value;

    original.value.rand_mode(0);
    original.dyn.rand_mode(0);
    original.dyn[1].rand_mode(1);
    original.queue_values.rand_mode(0);
    original.queue_values[0].rand_mode(1);
    original.assoc_values.rand_mode(0);
    original.assoc_values[4].rand_mode(1);
    original.harmless_c.constraint_mode(0);
    copied = new original;
    if (copied.value.rand_mode() !== 0)
      $fatal(1, "shallow copy did not copy rand_mode");
    if (copied.harmless_c.constraint_mode() !== 0)
      $fatal(1, "shallow copy did not copy constraint_mode");
    if (copied.dyn[0].rand_mode() !== 0 ||
        copied.dyn[1].rand_mode() !== 1 ||
        copied.dyn[2].rand_mode() !== 0)
      $fatal(1, "shallow copy did not copy dynamic-array rand_mode");
    if (copied.queue_values[0].rand_mode() !== 1 ||
        copied.queue_values[1].rand_mode() !== 0)
      $fatal(1, "shallow copy did not copy queue rand_mode");
    if (copied.assoc_values[4].rand_mode() !== 1 ||
        copied.assoc_values[9].rand_mode() !== 0)
      $fatal(1, "shallow copy did not copy associative-array rand_mode: %0d/%0d",
             copied.assoc_values[4].rand_mode(),
             copied.assoc_values[9].rand_mode());

    // The copied containers are distinct values. Their inherited aggregate
    // defaults also govern elements created after the class copy.
    copied.dyn[1].rand_mode(0);
    if (original.dyn[1].rand_mode() !== 1)
      $fatal(1, "dynamic-array mode storage aliased across shallow copy");
    copied.queue_values.push_back(3);
    if (copied.queue_values[$].rand_mode() !== 0)
      $fatal(1, "queue rand_mode default was not copied");
    copied.assoc_values[13] = 13;
    if (copied.assoc_values[13].rand_mode() !== 0)
      $fatal(1, "associative-array rand_mode default was not copied");

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
