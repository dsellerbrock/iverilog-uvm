module sv_array_map_dynamic_2023;
  typedef struct { int value; } map_item_t;
  typedef int map_row_t[1:0];

  int a[] = '{1, 2, 3};
  int b[] = '{2, 3, 5};
  int doubled[];
  int combined[$];
  int q[$] = '{4, 5};
  int q_mapped[$];
  int empty_q[$];
  int empty_q_mapped[$];
  int empty[];
  int empty_mapped[];
  bit comparison[];
  string formatted[];
  real halves[];
  map_item_t struct_source[];
  map_item_t struct_copy[];
  int struct_values[];
  map_row_t row_copy[];
  map_row_t row_copy_roundtrip[];
  map_row_t row_queue_copy[$];
  map_row_t row_queue_roundtrip[$];
  int row_source[string];
  map_row_t assoc_row_copy[string];
  map_row_t assoc_row_roundtrip[string];
  map_row_t empty_row_copy[];
  map_row_t empty_row_queue_copy[$];
  int empty_row_source[string];
  map_row_t empty_assoc_row_copy[string];

  function automatic map_row_t make_row(input int value);
    make_row[1] = value;
    make_row[0] = value + 1;
  endfunction

  initial begin
    doubled = a.map() with (item + 1'b1);
    if (doubled.size() != 3 || doubled[0] != 2
        || doubled[1] != 3 || doubled[2] != 4)
      $fatal(1, "dynamic map values: %p", doubled);

    combined = a.map(value, map_index) with (value + b[value.map_index]);
    if (combined.size() != 3 || combined[0] != 3
        || combined[1] != 5 || combined[2] != 8)
      $fatal(1, "custom iterator/index map values: %p", combined);

    comparison = a.map(value) with (value + 1 == b[value.index]);
    if (comparison.size() != 3 || !comparison[0]
        || !comparison[1] || comparison[2])
      $fatal(1, "mapped element type/values: %p", comparison);

    q_mapped = q.map() with (item * 3);
    if (q_mapped.size() != 2 || q_mapped[0] != 12 || q_mapped[1] != 15)
      $fatal(1, "queue map values: %p", q_mapped);

    empty_mapped = empty.map() with (item + 7);
    if (empty_mapped.size() != 0)
      $fatal(1, "empty map size: %p", empty_mapped);

    empty_q_mapped = empty_q.map() with (item * 2);
    if (empty_q_mapped.size() != 0)
      $fatal(1, "empty queue map size: %p", empty_q_mapped);

    formatted = a.map(value) with ($sformatf("v%0d", value));
    if (formatted.size() != 3 || formatted[0] != "v1"
        || formatted[1] != "v2" || formatted[2] != "v3")
      $fatal(1, "string map values: %p", formatted);

    halves = a.map(value) with (value / 2.0);
    if (halves.size() != 3 || halves[0] != 0.5
        || halves[1] != 1.0 || halves[2] != 1.5)
      $fatal(1, "real map values: %p", halves);

    struct_source = new[2];
    struct_source[0].value = 6;
    struct_source[1].value = 8;
    struct_copy = struct_source.map(value) with (value);
    struct_values = struct_source.map(value) with (value.value + 1);
    if (struct_copy.size() != 2 || struct_copy[0].value != 6
        || struct_copy[1].value != 8 || struct_values[0] != 7
        || struct_values[1] != 9)
      $fatal(1, "unpacked struct map values");

    row_copy = a.map(value) with (make_row(value));
    if (row_copy.size() != 3 || row_copy[0][1] != 1
        || row_copy[0][0] != 2 || row_copy[1][1] != 2
        || row_copy[1][0] != 3 || row_copy[2][1] != 3
        || row_copy[2][0] != 4)
      $fatal(1, "dynamic array-valued map result");
    row_copy_roundtrip = row_copy.map(row) with (row);
    if (row_copy_roundtrip.size() != 3 || row_copy_roundtrip[0][1] != 1
        || row_copy_roundtrip[0][0] != 2 || row_copy_roundtrip[2][1] != 3
        || row_copy_roundtrip[2][0] != 4)
      $fatal(1, "dynamic map over fixed-array elements");

    row_queue_copy = q.map(value) with (make_row(value));
    if (row_queue_copy.size() != 2 || row_queue_copy[0][1] != 4
        || row_queue_copy[0][0] != 5 || row_queue_copy[1][1] != 5
        || row_queue_copy[1][0] != 6)
      $fatal(1, "queue array-valued map result");
    row_queue_roundtrip = row_queue_copy.map(row) with (row);
    if (row_queue_roundtrip.size() != 2 || row_queue_roundtrip[0][1] != 4
        || row_queue_roundtrip[0][0] != 5 || row_queue_roundtrip[1][1] != 5
        || row_queue_roundtrip[1][0] != 6)
      $fatal(1, "queue map over fixed-array elements");

    row_source["a"] = 7;
    row_source["bb"] = 9;
    assoc_row_copy = row_source.map(value, key) with (make_row(value));
    if (assoc_row_copy.num() != 2 || !assoc_row_copy.exists("a")
        || !assoc_row_copy.exists("bb") || assoc_row_copy["a"][1] != 7
        || assoc_row_copy["a"][0] != 8 || assoc_row_copy["bb"][1] != 9
        || assoc_row_copy["bb"][0] != 10)
      $fatal(1, "associative array-valued map result");
    assoc_row_roundtrip = assoc_row_copy.map(row, key) with (row);
    if (assoc_row_roundtrip.num() != 2 || !assoc_row_roundtrip.exists("a")
        || !assoc_row_roundtrip.exists("bb")
        || assoc_row_roundtrip["a"][1] != 7
        || assoc_row_roundtrip["a"][0] != 8
        || assoc_row_roundtrip["bb"][1] != 9
        || assoc_row_roundtrip["bb"][0] != 10)
      $fatal(1, "associative map over fixed-array elements");

    empty_row_copy = empty.map(value) with (make_row(value));
    empty_row_queue_copy = empty_q.map(value) with (make_row(value));
    empty_assoc_row_copy = empty_row_source.map(value, key)
        with (make_row(value));
    if (empty_row_copy.size() != 0 || empty_row_queue_copy.size() != 0
        || empty_assoc_row_copy.num() != 0)
      $fatal(1, "empty array-valued map results");

    $display("PASSED");
  end
endmodule
