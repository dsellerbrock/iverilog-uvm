// IEEE 1800-2017/2023 8.4, 11.4.5, 18.4: handles compare by identity.
// Keep the unpacked record and its handle non-rand: this checks state identity,
// without requiring randomization of a class member inside a value struct.
class carrier_leaf;
  rand bit value;
  constraint c { value == 1; }
endclass

class carrier_box;
  carrier_leaf item;
endclass

typedef struct { carrier_leaf item; } handle_record_t;

class carrier_root;
  rand carrier_leaf left, right;
  carrier_box via;
  handle_record_t record;
  carrier_leaf fixed_values[3:2];
  carrier_leaf dynamic_values[];
  carrier_leaf queue_values[$];
  carrier_box boxes[];
  carrier_box box_queue[$];
  carrier_root self;
  bit same_expected, left_null_expected, right_null_expected;
  rand bit payload;

  function new();
    via = new;
    dynamic_values = new[2];
    boxes = new[2];
    boxes[0] = new;
    boxes[1] = new;
    self = this;
  endfunction

  constraint c {
    payload == 1;
    (left == right) == same_expected;
    (left != right) == !same_expected;
    (left == null) == left_null_expected;
    (null != right) == !right_null_expected;
    null == null;
    !(null != null);
    self == this;
    self != null;
    via.item == left;
    record.item == right;
    fixed_values[3] == left;
    fixed_values[2] == right;
    dynamic_values[0] == left;
    queue_values[1] == right;
    boxes[0].item == left;
    box_queue[1].item == right;
    foreach (dynamic_values[i])
      if (i == 0) dynamic_values[i] == left;
      else dynamic_values[i] == right;
    foreach (queue_values[i])
      if (i == 0) queue_values[i] == left;
      else queue_values[i] == right;
    foreach (boxes[i])
      if (i == 0) boxes[i].item == left;
      else boxes[i].item == right;
    foreach (box_queue[i])
      if (i == 0) box_queue[i].item == left;
      else box_queue[i].item == right;
  }
endclass

module main;
  carrier_leaf a, b;

  task automatic check_pair(input carrier_leaf x, input carrier_leaf y,
                            input bit same_expected,
                            input bit x_null, input bit y_null);
    carrier_root r;
    r = new;
    r.left = x;
    r.right = y;
    r.via.item = x;
    r.record.item = y;
    r.fixed_values[3] = x;
    r.fixed_values[2] = y;
    r.dynamic_values[0] = x;
    r.dynamic_values[1] = y;
    r.queue_values.push_back(x);
    r.queue_values.push_back(y);
    r.boxes[0].item = x;
    r.boxes[1].item = y;
    r.box_queue.push_back(r.boxes[0]);
    r.box_queue.push_back(r.boxes[1]);
    r.same_expected = same_expected;
    r.left_null_expected = x_null;
    r.right_null_expected = y_null;
    if (x != null) x.value = 0;
    if (y != null) y.value = 0;
    if (!r.randomize()) $fatal(1, "valid handle matrix rejected");
    if (r.payload != 1 || r.left !== x || r.right !== y)
      $fatal(1, "success changed handle identity or missed payload");
    if (r.via.item !== x || r.record.item !== y ||
        r.fixed_values[3] !== x || r.fixed_values[2] !== y ||
        r.dynamic_values[0] !== x || r.dynamic_values[1] !== y ||
        r.queue_values[0] !== x || r.queue_values[1] !== y ||
        r.boxes[0].item !== x || r.boxes[1].item !== y ||
        r.box_queue[0].item !== x || r.box_queue[1].item !== y ||
        (r.left === r.right) != same_expected ||
        (r.left !== r.right) != !same_expected ||
        (r.left === null) != x_null || (null !== r.right) != !y_null)
      $fatal(1, "procedural case equality disagreed with handle identity");
    if (x != null) if (x.value != 1) $fatal(1, "left leaf not solved");
    if (y != null) if (y.value != 1) $fatal(1, "right leaf not solved");

    // Contradict the actual identity and require whole-graph value rollback.
    r.same_expected = !same_expected;
    r.payload = 0;
    if (x != null) x.value = 0;
    if (y != null) y.value = 0;
    if (r.randomize()) $fatal(1, "false handle identity accepted");
    if (r.payload != 0 || r.left !== x || r.right !== y)
      $fatal(1, "failure changed payload or handles");
    if (x != null) if (x.value != 0) $fatal(1, "left leaf not rolled back");
    if (y != null) if (y.value != 0) $fatal(1, "right leaf not rolled back");
  endtask

  initial begin
    a = new;
    b = new;
    check_pair(a, a, 1, 0, 0);
    check_pair(a, b, 0, 0, 0);
    check_pair(null, a, 0, 1, 0);
    check_pair(a, null, 0, 0, 1);
    check_pair(null, null, 1, 1, 1);
    $display("PASSED");
  end
endmodule
