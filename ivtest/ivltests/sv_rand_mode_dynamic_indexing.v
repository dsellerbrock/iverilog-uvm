class mode_key;
  int id;
  function new(int value); id = value; endfunction
endclass

class dynamic_index_mode_item;
  rand bit [63:0] dynamic_values[];
  rand int dynamic_order[];
  rand bit [63:0] queue_values[$];
  rand int order_values[$];
  rand bit [31:0] empty_queue[$];
  rand bit [63:0] associative_values[int];
  rand bit [31:0] string_values[string];
  rand bit [31:0] object_values[mode_key];
  int wanted_size = 3;

  constraint values_c {
    dynamic_values.size() == wanted_size;
    queue_values.size() == wanted_size;
    foreach (associative_values[index]) associative_values[index] != 0;
    wanted_size <= 4;
  }
endclass

module test;
  initial begin
    automatic dynamic_index_mode_item item = new;
    automatic mode_key key = new(7);
    automatic mode_key missing_key = new(8);

    item.dynamic_values = new[3];
    item.dynamic_values = '{64'd0, 64'h77, 64'd0};
    item.dynamic_order = new[3];
    item.dynamic_order = '{30, 10, 20};
    item.queue_values = '{64'd0, 64'h88, 64'd0};
    item.order_values = '{30, 10, 20};
    item.associative_values[3] = 64'hdeadcafe_12345678;
    item.associative_values[4] = 64'd0;
    item.string_values["hold"] = 32'h11223344;
    item.string_values["move"] = 32'd0;
    item.object_values[key] = 32'h55667788;

    if (!item.dynamic_values[0].rand_mode()
        || !item.queue_values[0].rand_mode()
        || !item.associative_values[3].rand_mode()
        || !item.string_values["hold"].rand_mode()
        || !item.object_values[key].rand_mode())
      $fatal(1, "new element was not active");

    item.dynamic_values[1].rand_mode(0);
    item.queue_values[1].rand_mode(0);
    item.associative_values[3].rand_mode(0);
    item.string_values["hold"].rand_mode(0);
    item.object_values[key].rand_mode(0);
    if (item.dynamic_values[1].rand_mode() !== 0
        || item.queue_values[1].rand_mode() !== 0
        || item.associative_values[3].rand_mode() !== 0
        || item.string_values["hold"].rand_mode() !== 0
        || item.object_values[key].rand_mode() !== 0)
      $fatal(1, "indexed disable was not observable");

    // A queue's legal last-element index is evaluated against its live size.
    item.queue_values[$].rand_mode(0);
    if (item.queue_values[$].rand_mode() !== 0)
      $fatal(1, "queue last-element mode was not observable");
    item.queue_values[$].rand_mode(1);
    item.queue_values[$-1].rand_mode(1);
    if (item.queue_values[1].rand_mode() !== 1)
      $fatal(1, "queue relative-last element mode was not observable");
    item.queue_values[$-1].rand_mode(0);
    if (item.empty_queue[$].rand_mode() !== 0)
      $fatal(1, "empty queue last-element query did not return zero");
    item.empty_queue[$].rand_mode(0);
    if (item.empty_queue.size() != 0)
      $fatal(1, "empty queue last-element setter created an element");

    // Integral associative keys are converted to their declared key type;
    // alternate source widths still designate the same member variable.
    item.associative_values[8'd3].rand_mode(1);
    if (!item.associative_values[3].rand_mode())
      $fatal(1, "integral key conversion lost associative identity");
    item.associative_values[8'd3].rand_mode(0);

    if (item.dynamic_values[99].rand_mode() !== 0
        || item.queue_values[99].rand_mode() !== 0
        || item.associative_values[99].rand_mode() !== 0
        || item.string_values["missing"].rand_mode() !== 0
        || item.object_values[missing_key].rand_mode() !== 0)
      $fatal(1, "missing element query did not return zero");
    item.associative_values[99].rand_mode(0);
    item.string_values["missing"].rand_mode(0);
    item.object_values[missing_key].rand_mode(0);
    if (item.associative_values.exists(99)
        || item.string_values.exists("missing")
        || item.object_values.exists(missing_key))
      $fatal(1, "missing element setter inserted an entry");

    item.srandom(32'h31415926);
    if (!item.randomize()) $fatal(1, "mode-aware randomize failed");
    if (item.dynamic_values[0] === 64'd0
        || item.dynamic_values[1] !== 64'h77
        || item.dynamic_values[2] === 64'd0)
      $fatal(1, "dynamic element mode was not honored");
    if (item.queue_values[0] === 64'd0
        || item.queue_values[1] !== 64'h88
        || item.queue_values[2] === 64'd0)
      $fatal(1, "queue element mode was not honored");
    if (item.associative_values[3] !== 64'hdeadcafe_12345678
        || item.string_values["hold"] !== 32'h11223344
        || item.object_values[key] !== 32'h55667788)
      $fatal(1, "associative disabled entry changed");
    if (item.associative_values[4] === 64'd0
        || item.string_values["move"] === 32'd0)
      $fatal(1, "associative active entry did not randomize");

    // Queue mode follows an existing element as insertion shifts its index.
    item.queue_values.push_front(64'd9);
    if (!item.queue_values[0].rand_mode()
        || item.queue_values[2].rand_mode() !== 0)
      $fatal(1, "queue insertion did not preserve shifted mode");
    item.queue_values.delete(0);
    if (item.queue_values[1].rand_mode() !== 0)
      $fatal(1, "queue erase did not preserve shifted mode");

    // Ordering methods rearrange queue elements, so each element's mode must
    // follow the same permutation as its value. The shuffle check is phrased
    // as a value-to-mode invariant and does not depend on the random order.
    item.order_values[1].rand_mode(0);
    item.order_values.sort();
    if (item.order_values[0] != 10 || item.order_values[1] != 20
        || item.order_values[2] != 30
        || item.order_values[0].rand_mode() !== 0
        || !item.order_values[1].rand_mode()
        || !item.order_values[2].rand_mode())
      $fatal(1, "queue sort detached rand_mode from its element");
    item.order_values.reverse();
    if (item.order_values[0] != 30 || item.order_values[1] != 20
        || item.order_values[2] != 10
        || !item.order_values[0].rand_mode()
        || !item.order_values[1].rand_mode()
        || item.order_values[2].rand_mode() !== 0)
      $fatal(1, "queue reverse detached rand_mode from its element");
    item.order_values.shuffle();
    foreach (item.order_values[index]) begin
      if ((item.order_values[index] == 10)
          != (item.order_values[index].rand_mode() === 0))
        $fatal(1, "queue shuffle detached rand_mode from its element");
    end
    item.order_values.sort(element) with (element);
    if (item.order_values[0] != 10 || item.order_values[1] != 20
        || item.order_values[2] != 30
        || item.order_values[0].rand_mode() !== 0
        || !item.order_values[1].rand_mode()
        || !item.order_values[2].rand_mode())
      $fatal(1, "keyed queue sort detached rand_mode from its element");

    // A dynamic array has persistent indexed variables rather than shifting
    // queue members. Ordering assigns rearranged values into those variables,
    // so the disabled mode remains at its original index.
    item.dynamic_order[1].rand_mode(0);
    item.dynamic_order.sort();
    if (item.dynamic_order[0] != 10 || item.dynamic_order[1] != 20
        || item.dynamic_order[2] != 30
        || !item.dynamic_order[0].rand_mode()
        || item.dynamic_order[1].rand_mode() !== 0
        || !item.dynamic_order[2].rand_mode())
      $fatal(1, "dynamic-array ordering moved indexed rand_mode state");

    // Deleting a key destroys that element variable. Reinserted keys inherit
    // the property-wide default and do not resurrect the old override.
    item.associative_values.delete(3);
    item.associative_values[3] = 64'h1234;
    if (!item.associative_values[3].rand_mode())
      $fatal(1, "reinserted associative key kept stale mode");

    // A whole-property setter controls existing and subsequently created
    // elements. The IEEE query form remains singular and is tested negative
    // separately rather than assigning extension semantics here.
    item.dynamic_values.rand_mode(0);
    item.queue_values.rand_mode(0);
    item.associative_values.rand_mode(0);
    item.dynamic_values = new[4](item.dynamic_values);
    item.queue_values.push_back(64'd10);
    item.associative_values[10] = 64'd10;
    if (item.dynamic_values[3].rand_mode() !== 0
        || item.queue_values[item.queue_values.size()-1].rand_mode() !== 0
        || item.associative_values[10].rand_mode() !== 0)
      $fatal(1, "new element ignored property-wide default mode");
    item.dynamic_values.rand_mode(1);
    item.queue_values.rand_mode(1);
    item.associative_values.rand_mode(1);
    if (!item.dynamic_values[0].rand_mode()
        || !item.queue_values[0].rand_mode()
        || !item.associative_values[3].rand_mode())
      $fatal(1, "whole-property enable did not reach existing elements");

    // A failed solve restores both values and mode metadata.
    item.dynamic_values[1].rand_mode(0);
    item.wanted_size = 5;
    if (item.randomize() !== 0) $fatal(1, "contradictory solve succeeded");
    if (item.dynamic_values[1].rand_mode() !== 0)
      $fatal(1, "failed solve lost dynamic element mode");

    $display("PASSED");
  end
endmodule
