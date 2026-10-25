// IEEE 1800-2017 §18.9, pp. 534–535; IEEE 1800-2023 §18.9, pp. 556–557.
class Base;
  rand int val_base;
  constraint c_base { val_base inside {[10:20]}; }
endclass

class Item extends Base;
  rand int val_item;
  constraint c_item { val_item inside {[100:200]}; }
  constraint c_extra { val_item != 150; }
endclass

module test;
  initial begin
    Item it = new;

    if (it.c_base.constraint_mode() !== 1
        || it.c_item.constraint_mode() !== 1
        || it.c_extra.constraint_mode() !== 1)
      $fatal(1, "constraints were not initially enabled");

    it.c_base.constraint_mode(0);
    if (it.c_base.constraint_mode() !== 0)
      $fatal(1, "named constraint_mode(0) failed");
    if (!it.randomize() with { val_base == 999; })
      $fatal(1, "disabled inherited constraint still restricted randomize()");
    if (it.val_base !== 999)
      $fatal(1, "disabled inherited constraint did not permit the inline value");

    it.c_base.constraint_mode(1);
    if (it.c_base.constraint_mode() !== 1)
      $fatal(1, "named constraint_mode(1) failed");
    if (it.randomize() with { val_base == 999; })
      $fatal(1, "re-enabled inherited constraint was not enforced");

    it.constraint_mode(0);
    if (it.c_base.constraint_mode() !== 0
        || it.c_item.constraint_mode() !== 0
        || it.c_extra.constraint_mode() !== 0)
      $fatal(1, "object-wide constraint_mode(0) did not disable all constraints");
    if (!it.randomize() with { val_item == 150; })
      $fatal(1, "object-wide disable left a class constraint active");
    if (it.val_item !== 150)
      $fatal(1, "inline constraint did not assign the requested value");

    it.constraint_mode(1);
    if (it.c_base.constraint_mode() !== 1
        || it.c_item.constraint_mode() !== 1
        || it.c_extra.constraint_mode() !== 1)
      $fatal(1, "object-wide constraint_mode(1) did not enable all constraints");

    $display("PASS constraint_mode clause 18.9");
  end
endmodule
