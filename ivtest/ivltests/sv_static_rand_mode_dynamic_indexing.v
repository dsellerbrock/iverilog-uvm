class static_container_mode_item;
  static rand int dynamic_values[];
  static rand int queue_values[$];
  static rand int associative_values[int];
endclass

module test;
  initial begin
    automatic static_container_mode_item first = new;
    automatic static_container_mode_item second = new;

    static_container_mode_item::dynamic_values = new[2];
    static_container_mode_item::queue_values = '{1, 2};
    static_container_mode_item::associative_values[3] = 3;

    first.dynamic_values[0].rand_mode(0);
    first.queue_values[1].rand_mode(0);
    first.associative_values[3].rand_mode(0);
    if (second.dynamic_values[0].rand_mode() !== 0
        || second.queue_values[1].rand_mode() !== 0
        || second.associative_values[3].rand_mode() !== 0)
      $fatal(1, "static container element modes were not shared");

    second.associative_values.rand_mode(0);
    first.associative_values[4] = 4;
    if (first.associative_values[4].rand_mode() !== 0)
      $fatal(1, "static property-wide default was not shared");
    first.associative_values.rand_mode(1);
    if (!second.associative_values[3].rand_mode()
        || !second.associative_values[4].rand_mode())
      $fatal(1, "static property-wide enable was not shared");

    $display("PASSED");
  end
endmodule
