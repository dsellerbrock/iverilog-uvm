// IEEE 1800-2017/2023 7.6, 7.9.9, 7.9.11, 10.4.1, 10.9.1
typedef logic [7:0] octet_t;
typedef octet_t row_t[3:2];
typedef row_t map_t[int];
typedef octet_t queue_t[$];
typedef octet_t darray_t[];

class key_t;
endclass

typedef map_t by_handle_t[key_t];
typedef map_t bounded_maps_t[$:1];

module top;
  map_t fixed_maps[6:5];
  map_t dynamic_maps[];
  map_t queue_maps[$:1];
  by_handle_t maps;
  by_handle_t deep[string];
  bounded_maps_t positional[int];
  key_t slot, sibling;
  queue_t q;
  darray_t d;
  int rhs_calls, selector_calls;

  function automatic queue_t from_queue(input int digit, input bit short_value);
    queue_t result;
    rhs_calls = 10 * rhs_calls + digit;
    result = q;
    if (short_value)
      void'(result.pop_back());
    return result;
  endfunction

  function automatic darray_t from_dynamic(input int digit, input bit short_value);
    darray_t result;
    rhs_calls = 10 * rhs_calls + digit;
    if (!short_value)
      result = d;
    return result;
  endfunction

  function automatic int fixed_slot();
    selector_calls++;
    // The checked items have already been copied when the selector runs.
    q[0] = 0;
    d[0] = 0;
    return 6;
  endfunction

  function automatic key_t inner_key();
    selector_calls++;
    return slot;
  endfunction

  task automatic calls(input int expected);
    if (rhs_calls != expected)
      $fatal(1, "expected RHS calls %0d, got %0d", expected, rhs_calls);
    rhs_calls = 0;
  endtask

  task automatic check(input map_t m, input int key,
                       input logic [15:0] words, input logic [15:0] fallback);
    if (m.num() != 1 || !m.exists(key) || m.exists(99)
        || {m[key][3], m[key][2]} !== words
        || {m[99][3], m[99][2]} !== fallback)
      $fatal(1, "map mismatch for key %0d (size %0d)", key, m.num());
  endtask

  initial begin
    map_t old_map, sibling_map;
    logic signed [31:0] undefined_slot;
    q = '{8'hx1, 8'h23};
    d = new[2]; d[0] = 8'h45; d[1] = 8'hz6;
    slot = new; sibling = new;
    old_map = '{7: '{11, 12}, default: '{13, 14}};
    sibling_map = '{8: '{21, 22}, default: '{23, 24}};

    fixed_maps[6] = old_map;
    fixed_maps[5] = sibling_map;
    fixed_maps[fixed_slot()] = '{9: from_queue(1, 1), default: from_dynamic(2, 0)};
    calls(12);
    if (selector_calls != 0)
      $fatal(1, "failed pattern evaluated fixed selector");
    check(fixed_maps[6], 7, 16'h0b0c, 16'h0d0e);
    check(fixed_maps[5], 8, 16'h1516, 16'h1718);
    fixed_maps[fixed_slot()] = '{9: from_queue(3, 0), default: from_dynamic(4, 0)};
    calls(34);
    if (selector_calls != 1 || q[0] !== 0 || d[0] !== 0)
      $fatal(1, "fixed selector did not run exactly once");
    if ({fixed_maps[6][9][3], fixed_maps[6][9][2]} !== 16'hx123)
      $fatal(1, "fixed-slot store lost the row's descending range");
    check(fixed_maps[6], 9, 16'hx123, 16'h45z6);
    check(fixed_maps[5], 8, 16'h1516, 16'h1718);
    q[0] = 8'hx1; d[0] = 8'h45;

    fixed_maps[undefined_slot] = '{9: from_dynamic(1, 0), default: from_queue(2, 0)};
    calls(12);
    check(fixed_maps[6], 9, 16'hx123, 16'h45z6);
    check(fixed_maps[5], 8, 16'h1516, 16'h1718);

    dynamic_maps = new[2];
    dynamic_maps[0] = old_map;
    dynamic_maps[1] = sibling_map;
    dynamic_maps[0] = '{default: from_queue(1, 0), 9: from_dynamic(2, 1)};
    calls(12);
    check(dynamic_maps[0], 7, 16'h0b0c, 16'h0d0e);
    check(dynamic_maps[1], 8, 16'h1516, 16'h1718);
    dynamic_maps[0] = '{default: from_queue(3, 0), 9: from_dynamic(4, 0)};
    calls(34);
    check(dynamic_maps[0], 9, 16'h45z6, 16'hx123);
    check(dynamic_maps[1], 8, 16'h1516, 16'h1718);
    dynamic_maps[0] = '{9: d, default: q};
    d[1] = 0; q[1] = 0;
    check(dynamic_maps[0], 9, 16'h45z6, 16'hx123);
    check(dynamic_maps[1], 8, 16'h1516, 16'h1718);
    d[1] = 8'hz6; q[1] = 8'h23;

    queue_maps[0] = old_map;
    queue_maps[1] = sibling_map;
    queue_maps[0] = '{default: from_queue(1, 1)};
    calls(1);
    check(queue_maps[0], 7, 16'h0b0c, 16'h0d0e);
    check(queue_maps[1], 8, 16'h1516, 16'h1718);
    queue_maps[0] = '{default: from_queue(2, 0)};
    calls(2);
    if (queue_maps.size() != 2 || queue_maps[0].num() != 0
        || queue_maps[0].exists(7)
        || {queue_maps[0][99][3], queue_maps[0][99][2]} !== 16'hx123)
      $fatal(1, "queue slot default-only replacement");
    check(queue_maps[1], 8, 16'h1516, 16'h1718);

    maps[slot] = old_map;
    maps[sibling] = sibling_map;
    maps[slot] = '{9: from_queue(1, 0), default: from_dynamic(2, 1)};
    calls(12);
    check(maps[slot], 7, 16'h0b0c, 16'h0d0e);
    check(maps[sibling], 8, 16'h1516, 16'h1718);
    maps[slot] = '{9: from_queue(3, 0), default: from_dynamic(4, 0)};
    calls(34);
    check(maps[slot], 9, 16'hx123, 16'h45z6);
    check(maps[sibling], 8, 16'h1516, 16'h1718);

    // A failed builder must branch around associative vivification.
    deep["existing"][sibling] = sibling_map;
    deep["new"][inner_key()] = '{9: from_queue(1, 0), default: from_dynamic(2, 1)};
    calls(12);
    if (deep.exists("new") || deep.num() != 1 || selector_calls != 1)
      $fatal(1, "failed pattern touched a missing outer key or its selector");
    check(deep["existing"][sibling], 8, 16'h1516, 16'h1718);
    deep["new"][inner_key()] = '{9: from_queue(3, 0), default: from_dynamic(4, 0)};
    calls(34);
    if (!deep.exists("new") || !deep["new"].exists(slot) || deep.num() != 2
        || selector_calls != 2)
      $fatal(1, "successful pattern did not create the selected keys once");
    check(deep["new"][slot], 9, 16'hx123, 16'h45z6);
    check(deep["existing"][sibling], 8, 16'h1516, 16'h1718);

    positional[4][0] = '{default: from_queue(1, 1)};
    calls(1);
    if (positional.exists(4))
      $fatal(1, "failed positional leaf store created its outer key");
    positional[4][0] = '{9: from_dynamic(2, 0), default: from_queue(3, 0)};
    calls(23);
    if (!positional.exists(4) || positional[4].size() != 1)
      $fatal(1, "successful positional leaf store did not append");
    check(positional[4][0], 9, 16'h45z6, 16'hx123);

    $display("PASSED");
  end
endmodule
