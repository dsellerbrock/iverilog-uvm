// A package-qualified class name may consume its #(...) arguments before the
// enclosing extends production sees it.  Losing those arguments selects the
// defaults and can make a factory construct one class layout while methods
// access it using a different specialization's property indices.

package package_param_extends_base_pkg;
  class base_item;
  endclass

  class selected_item extends base_item;
  endclass

  class registry #(type T = base_item);
    static function T create;
      T object = new;
      return object;
    endfunction
  endclass

  class item_queue #(type E = base_item);
    E expected_items[$];
    E actual_items[$];
    bit [63:0] expected_items_timestamp[$];
    bit [63:0] actual_items_timestamp[$];
    typedef registry#(item_queue#(E)) type_id;

    function void add_expected(E item);
      expected_items.push_back(item);
      expected_items_timestamp.push_back(1);
    endfunction

    function void add_actual(E item);
      actual_items.push_back(item);
      actual_items_timestamp.push_back(2);
    endfunction
  endclass

  class scoreboard #(type ITEM_T = base_item);
    item_queue#(ITEM_T) queue;

    function void build;
      queue = item_queue#(ITEM_T)::type_id::create();
    endfunction

    function void add(ITEM_T item);
      queue.add_expected(item);
      queue.add_actual(item);
    endfunction
  endclass
endpackage

package package_param_extends_user_pkg;
  import package_param_extends_base_pkg::*;

  class derived extends package_param_extends_base_pkg::scoreboard #(
      .ITEM_T(selected_item));
  endclass
endpackage

module sv_package_param_class_extends;
  import package_param_extends_base_pkg::*;
  import package_param_extends_user_pkg::*;

  derived object;
  selected_item item;

  initial begin
    object = new;
    item = new;
    object.build();
    object.add(item);

    if (object.queue.expected_items.size() != 1
        || object.queue.expected_items_timestamp.size() != 1
        || object.queue.actual_items.size() != 1
        || object.queue.actual_items_timestamp.size() != 1) begin
      $display("FAILED queue sizes %0d %0d %0d %0d",
          object.queue.expected_items.size(),
          object.queue.expected_items_timestamp.size(),
          object.queue.actual_items.size(),
          object.queue.actual_items_timestamp.size());
      $finish;
    end

    $display("PASSED");
  end
endmodule
