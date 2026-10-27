// IEEE 1800-2017/2023 18.8: active state, selected/all-variable setters,
// state-variable solving, randc, object handles, arrays, and static sharing.
class rand_mode_base;
  rand int inherited;
endclass

class rand_mode_leaf extends rand_mode_base;
  rand bit [3:0] value;
  randc bit [3:0] cycle;
endclass

class rand_mode_item;
  rand bit [3:0] enabled;
  rand bit [3:0] held;
  rand rand_mode_leaf child;
  rand bit [1:0] words[3];
  static rand bit shared;

  constraint fixed_values {
    enabled == 5;
    held inside {[1:9]};
    foreach (words[i]) words[i] == i;
  }
endclass

module test;
  initial begin
    rand_mode_item first = new;
    rand_mode_item second = new;
    first.child = new;
    second.child = new;

    if (first.enabled.rand_mode() !== 1 || first.held.rand_mode() !== 1
        || !first.child.rand_mode() || !first.child.cycle.rand_mode()
        || !first.child.inherited.rand_mode()
        || !first.words[0].rand_mode() || !first.shared.rand_mode())
      $fatal(1, "random variables did not start active");

    first.held = 4;
    first.held.rand_mode(0);
    if (first.held.rand_mode() !== 0 || first.randomize() !== 1
        || first.held !== 4)
      $fatal(1, "disabled rand variable did not remain state");
    first.held = 0;
    if (first.randomize() !== 0)
      $fatal(1, "disabled state variable was incorrectly solved");
    first.held = 4;
    first.held.rand_mode(1);
    if (first.held.rand_mode() !== 1 || first.randomize() !== 1)
      $fatal(1, "selected rand variable did not re-enable");

    first.child.rand_mode(0);
    if (first.child.rand_mode() !== 0 || first.child.value.rand_mode() !== 1)
      $fatal(1, "object-handle mode changed a child variable's mode");
    first.child.rand_mode(1);
    first.child.inherited.rand_mode(0);
    if (first.child.inherited.rand_mode() !== 0)
      $fatal(1, "inherited random variable could not be selected");
    first.child.inherited.rand_mode(1);

    first.words[1].rand_mode(0);
    if (first.words[0].rand_mode() !== 1 || first.words[1].rand_mode() !== 0
        || first.words[2].rand_mode() !== 1)
      $fatal(1, "selected array element mode was not isolated");
    first.words.rand_mode(0);
    if (first.words[0].rand_mode() !== 0 || first.words[1].rand_mode() !== 0
        || first.words[2].rand_mode() !== 0)
      $fatal(1, "whole-array setter did not affect every element");
    first.words.rand_mode(1);

    first.rand_mode(0);
    if (first.enabled.rand_mode() !== 0 || first.held.rand_mode() !== 0
        || first.child.rand_mode() !== 0 || first.words[2].rand_mode() !== 0)
      $fatal(1, "object-wide setter did not disable every random variable");
    first.rand_mode(1);

    first.shared.rand_mode(0);
    if (first.shared.rand_mode() !== 0 || second.shared.rand_mode() !== 0)
      $fatal(1, "static rand_mode state was not shared across instances");
    second.shared.rand_mode(1);

    $display("PASS rand_mode clause 18.8");
  end
endmodule
