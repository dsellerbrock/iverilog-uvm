// A hidden static property has a distinct declaring cell. An upcast view of
// a derived object still selects the base declaration, while sibling object
// views share the appropriate base or derived VALUE+rand_mode cell.
class static_base_item;
  static rand int shared;

  constraint base_value {
    shared == 101;
  }
endclass

class static_derived_item extends static_base_item;
  static rand int shared;

  constraint derived_value {
    shared == 202;
  }
endclass

module test;
  initial begin
    static_base_item base_first;
    static_base_item base_second;
    static_base_item base_view;
    static_derived_item derived_first;
    static_derived_item derived_second;

    base_first = new;
    base_second = new;
    derived_first = new;
    derived_second = new;
    base_view = derived_first;

    static_base_item::shared = 11;
    static_derived_item::shared = 22;
    if (base_first.shared !== 11 || base_second.shared !== 11
        || base_view.shared !== 11)
      $fatal(1, "base declaring storage was not shared");
    if (derived_first.shared !== 22 || derived_second.shared !== 22)
      $fatal(1, "derived declaring storage was not shared");

    derived_first.shared = 23;
    base_view.shared = 12;
    if (static_derived_item::shared !== 23
        || derived_second.shared !== 23
        || static_base_item::shared !== 12
        || base_second.shared !== 12)
      $fatal(1, "hidden base and derived values aliased or split");

    base_view.shared.rand_mode(0);
    if (base_first.shared.rand_mode() !== 0
        || derived_first.shared.rand_mode() !== 1)
      $fatal(1, "base rand_mode did not follow the declaring cell");
    base_second.shared.rand_mode(1);
    derived_first.shared.rand_mode(0);
    if (derived_second.shared.rand_mode() !== 0
        || base_view.shared.rand_mode() !== 1)
      $fatal(1, "hidden derived rand_mode aliased base mode");
    derived_second.shared.rand_mode(1);

    if (derived_first.randomize() !== 1)
      $fatal(1, "derived randomize failed");
    if (static_base_item::shared !== 101
        || base_second.shared !== 101
        || static_derived_item::shared !== 202
        || derived_second.shared !== 202)
      $fatal(1, "derived randomize did not update both declaring cells");

    $display("PASSED");
  end
endmodule
