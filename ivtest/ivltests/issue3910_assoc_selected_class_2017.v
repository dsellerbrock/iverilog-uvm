// IEEE 1800-2017/2023 7.6, 7.9.9, 7.9.11, 10.4.1, 10.9.1
typedef bit [7:0] octet_t;
typedef octet_t row_t[4:3];
typedef row_t map_t[string];
typedef octet_t queue_t[$];
typedef octet_t darray_t[];

class key_t;
endclass

typedef map_t by_handle_t[key_t];

class holder;
  map_t fixed_maps[7:6];
  map_t dynamic_maps[];
  map_t queue_maps[$:1];
  by_handle_t maps;
  by_handle_t fixed_outer[7:6];
  by_handle_t dynamic_outer[];
  by_handle_t deep[key_t];
  map_t single;
endclass

module top;
  holder c, absent, objects[2];
  key_t slot, sibling;
  int rhs_calls, selector_calls;

  function automatic darray_t from_dynamic(input int digit, input int length);
    darray_t d;
    rhs_calls = 10 * rhs_calls + digit;
    d = new[length];
    foreach (d[i]) d[i] = 10 * digit + i;
    return d;
  endfunction

  function automatic queue_t from_queue(input int digit, input int length);
    queue_t q;
    rhs_calls = 10 * rhs_calls + digit;
    for (int i = 0; i < length; i++) q.push_back(10 * digit + i);
    return q;
  endfunction

  function automatic key_t select_key();
    selector_calls++;
    return slot;
  endfunction

  task automatic calls(input int expected);
    if (rhs_calls != expected)
      $fatal(1, "expected RHS calls %0d, got %0d", expected, rhs_calls);
    rhs_calls = 0;
  endtask

  task automatic check(input map_t m, input string key,
                       input bit [15:0] words, input bit [15:0] fallback);
    if (m.num() != 1 || !m.exists(key) || m.exists("missing")
        || {m[key][4], m[key][3]} !== words
        || {m["missing"][4], m["missing"][3]} !== fallback)
      $fatal(1, "map mismatch for key %s (size %0d)", key, m.num());
  endtask

  initial begin
    map_t old_map, sibling_map;
    int word_index;
    word_index = 7;
    c = new;
    objects[0] = new;
    slot = new; sibling = new;
    old_map = '{"old": '{1, 2}, default: '{3, 4}};
    sibling_map = '{"sibling": '{5, 6}, default: '{7, 8}};

    c.fixed_maps[word_index] = old_map;
    c.fixed_maps[6] = sibling_map;
    c.fixed_maps[word_index] = '{"new": from_queue(1, 2), default: from_dynamic(2, 1)};
    calls(12);
    check(c.fixed_maps[word_index], "old", 16'h0102, 16'h0304);
    check(c.fixed_maps[6], "sibling", 16'h0506, 16'h0708);
    c.fixed_maps[word_index] = '{"new": from_queue(1, 2), default: from_dynamic(2, 2)};
    calls(12);
    check(c.fixed_maps[word_index], "new", 16'h0a0b, 16'h1415);
    check(c.fixed_maps[6], "sibling", 16'h0506, 16'h0708);

    c.dynamic_maps = new[2];
    c.dynamic_maps[0] = old_map;
    c.dynamic_maps[1] = sibling_map;
    c.dynamic_maps[0] = '{default: from_queue(3, 1)};
    calls(3);
    check(c.dynamic_maps[0], "old", 16'h0102, 16'h0304);
    check(c.dynamic_maps[1], "sibling", 16'h0506, 16'h0708);
    c.dynamic_maps[0] = '{default: from_queue(4, 2), "new": from_dynamic(5, 2)};
    calls(45);
    check(c.dynamic_maps[0], "new", 16'h3233, 16'h2829);
    check(c.dynamic_maps[1], "sibling", 16'h0506, 16'h0708);

    c.queue_maps[0] = old_map;
    c.queue_maps[1] = sibling_map;
    c.queue_maps[0] = '{"new": from_dynamic(1, 3), default: from_queue(2, 2)};
    calls(12);
    check(c.queue_maps[0], "old", 16'h0102, 16'h0304);
    check(c.queue_maps[1], "sibling", 16'h0506, 16'h0708);
    c.queue_maps[0] = '{"new": from_dynamic(3, 2), default: from_queue(4, 2)};
    calls(34);
    check(c.queue_maps[0], "new", 16'h1e1f, 16'h2829);
    check(c.queue_maps[1], "sibling", 16'h0506, 16'h0708);

    c.maps[slot] = old_map;
    c.maps[sibling] = sibling_map;
    c.maps[select_key()] = '{"new": from_queue(1, 3), default: from_dynamic(2, 2)};
    calls(12);
    check(c.maps[slot], "old", 16'h0102, 16'h0304);
    check(c.maps[sibling], "sibling", 16'h0506, 16'h0708);
    c.maps[select_key()] = '{"new": from_queue(3, 2), default: from_dynamic(4, 2)};
    calls(34);
    if (selector_calls != 1)
      $fatal(1, "object key was evaluated on failure or more than once on success");
    check(c.maps[slot], "new", 16'h1e1f, 16'h2829);
    check(c.maps[sibling], "sibling", 16'h0506, 16'h0708);

    // Fixed property slot followed by an object key uses the nested lvalue walk.
    c.fixed_outer[6][sibling] = sibling_map;
    c.fixed_outer[word_index][select_key()] = '{default: from_dynamic(1, 0)};
    calls(1);
    if (c.fixed_outer[word_index].exists(slot) || selector_calls != 1)
      $fatal(1, "failed pattern touched a new nested slot or key");
    c.fixed_outer[word_index][select_key()] =
        '{"new": from_queue(5, 2), default: from_dynamic(6, 2)};
    calls(56);
    if (selector_calls != 2)
      $fatal(1, "nested object key was evaluated more than once");
    if ({c.fixed_outer[word_index][slot]["new"][4],
         c.fixed_outer[word_index][slot]["new"][3]} !== 16'h3233)
      $fatal(1, "nested property store lost the row's descending range");
    check(c.fixed_outer[word_index][slot], "new", 16'h3233, 16'h3c3d);
    check(c.fixed_outer[6][sibling], "sibling", 16'h0506, 16'h0708);

    // A positional navigation hop must also wait for the checked builder.
    objects[0].dynamic_outer = new[2];
    objects[0].dynamic_outer[0][select_key()] = '{"new": from_dynamic(1, 0)};
    calls(1);
    if (selector_calls != 2 || objects[0].dynamic_outer[0].exists(slot))
      $fatal(1, "failed pattern touched a dynamic outer slot");
    objects[0].dynamic_outer[0][select_key()] =
        '{"new": from_dynamic(2, 2), default: from_queue(3, 2)};
    calls(23);
    if (selector_calls != 3 || objects[0].dynamic_outer[1].num() != 0)
      $fatal(1, "dynamic outer slot selection");
    check(objects[0].dynamic_outer[0][slot], "new", 16'h1415, 16'h1e1f);

    // Reach a missing associative child through an indexed class handle.
    objects[0].deep[sibling][select_key()] = '{default: from_queue(1, 1)};
    calls(1);
    if (objects[0].deep.exists(sibling) || selector_calls != 3)
      $fatal(1, "failed pattern touched a missing class outer key");
    objects[0].deep[sibling][select_key()] =
        '{"new": from_queue(2, 2), default: from_dynamic(3, 2)};
    calls(23);
    if (!objects[0].deep.exists(sibling) || selector_calls != 4)
      $fatal(1, "successful pattern did not create the class outer key");
    check(objects[0].deep[sibling][slot], "new", 16'h1415, 16'h1e1f);

    objects[0].single = '{"new": from_dynamic(1, 2), default: from_queue(2, 2)};
    calls(12);
    objects[0].single = '{"bad": from_dynamic(3, 0)};
    calls(3);
    check(objects[0].single, "new", 16'h0a0b, 16'h1415);

    // Valid builders must be discarded on a null receiver without re-evaluating
    // the RHS or disturbing a following assignment's object stack.
    absent.fixed_maps[7] = '{"new": from_dynamic(1, 2)};
    calls(1);
    absent.fixed_outer[7][select_key()] = '{"new": from_queue(2, 2)};
    calls(2);
    if (selector_calls != 5)
      $fatal(1, "remaining index of a null nested receiver was not evaluated");
    check(c.fixed_outer[word_index][slot], "new", 16'h3233, 16'h3c3d);

    $display("PASSED");
  end
endmodule
