// IEEE 1800-2023 7.12.1: locator methods operate on every unpacked array.
// A fixed-array class property is materialized once, but its declared index
// and direction still define iterator.index and the first/last edge.
module sv_array_locator_fixed_property;
  typedef bit [31:0] uint_t;

  class token;
    int id;

    function new(int value);
      id = value;
    endfunction
  endclass

  class holder;
    uint_t asc[0:3];
    logic signed [7:0] desc[5:2];
    string names[-1:2];
    real weights[3:1];
    token objects[10:12];
    int receiver_calls;

    function holder once();
      receiver_calls++;
      return this;
    endfunction
  endclass

  holder h;
  uint_t values[$];
  int indexes[$];
  logic signed [7:0] signed_values[$];
  string strings[$];
  real reals[$];
  token objects[$];
  token object0, object1, object2;
  int one_result_index;
  bit failed;

  task automatic check(string label, bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1;
    end
  endtask

  initial begin
    h = new;
    h.asc = '{1, 16, 7, 16};
    h.desc = '{50, 40, 30, 20};
    h.names = '{"left", "skip", "keep", "right"};
    h.weights = '{3.5, 2.5, 1.5};
    object0 = new(10);
    object1 = new(11);
    object2 = new(12);
    h.objects[10] = object0;
    h.objects[11] = object1;
    h.objects[12] = object2;

    // This is the reduced OpenTitan GPIO stable-cycle filter.
    values = h.asc.find(m) with (m != 16);
    check("OpenTitan find values", values.size() == 2
          && ((values[0] == 1 && values[1] == 7)
              || (values[0] == 7 && values[1] == 1)));
    indexes = h.asc.find_index(m) with (m == 7 && m.index == 2);
    check("find_index and item.index", indexes.size() == 1
          && indexes[0] == 2);

    signed_values = h.desc.find_first(m) with (m >= 30);
    check("descending find_first", signed_values.size() == 1
          && signed_values[0] == 50);
    indexes = h.desc.find_first_index(m) with (m >= 30);
    check("descending find_first_index", indexes.size() == 1
          && indexes[0] == 5);
    signed_values = h.desc.find_last(m) with (m >= 30);
    check("descending find_last", signed_values.size() == 1
          && signed_values[0] == 30);
    indexes = h.desc.find_last_index(m) with (m >= 30);
    check("descending find_last_index", indexes.size() == 1
          && indexes[0] == 3);

    strings = h.names.find(m) with (m != "skip");
    check("string values", strings.size() == 3);
    indexes = h.names.find_index(m) with
      (m == "keep" && m.index() == 1);
    check("negative index base", indexes.size() == 1
          && indexes[0] == 1);

    reals = h.weights.find_last(m) with (m > 1.0);
    check("real descending value", reals.size() == 1
          && reals[0] == 1.5);
    indexes = h.weights.find_first_index(m) with (m > 1.0);
    check("real descending index", indexes.size() == 1
          && indexes[0] == 3);

    objects = h.objects.find(m) with (m.id >= 11);
    check("class-handle values", objects.size() == 2
          && objects[0].id + objects[1].id == 23);

    values = h.asc.find(m) with (m != 16);
    one_result_index = -1;
    foreach (values[i])
      if (values[i] == 1)
        one_result_index = i;
    h.asc[0] = 99;
    check("packed result snapshots property values", values.size() == 2
          && one_result_index >= 0 && values[one_result_index] == 1);
    if (one_result_index >= 0)
      values[one_result_index] = 88;
    check("result mutation leaves property unchanged", h.asc[0] == 99);

    values = h.once().asc.find(m) with (m == 7);
    check("receiver evaluated once", h.receiver_calls == 1
          && values.size() == 1 && values[0] == 7);

    values = h.asc.find(m) with (m == 1234);
    check("no match is empty", values.size() == 0);

    if (failed)
      $fatal(1, "fixed property locator checks failed");
    $display("PASSED");
  end
endmodule
