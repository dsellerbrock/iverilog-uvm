// IEEE 1800-2017/2023 7.12.1: locator results preserve aggregate value-copy
// semantics and retain identity for class handles.
typedef struct { int value; int tag; } locator_record_t;

class locator_handle_t;
  int value;
  function new(int v); value = v; endfunction
endclass

module sv_array_locator_aggregate;
  locator_record_t records[2];
  locator_record_t dynamic_records[];
  locator_record_t found[$];
  locator_handle_t handles[2];
  locator_handle_t found_handles[$];
  int count;
  bit choose_first;

  function automatic int count_records(input locator_record_t items[$]);
    return items.size();
  endfunction

  initial begin
    dynamic_records = new[2];
    records[0] = '{10, 1};
    records[1] = '{20, 2};
    dynamic_records[0] = records[0];
    dynamic_records[1] = records[1];
    handles[0] = new(30);
    handles[1] = new(40);

    count = count_records(records.find(row) with (row.value > 0));
    if (count != 2)
      $fatal(1, "aggregate locator function argument type failed");

    choose_first = 1;
    found = choose_first
      ? records.find_first(row) with (row.tag == 1)
      : records.find_first(row) with (row.tag == 2);
    if (found.size() != 1 || found[0].tag != 1)
      $fatal(1, "aggregate locator conditional result type failed");
    found[0].value = 99;
    if (records[0].value != 10)
      $fatal(1, "fixed-array aggregate result aliases source");

    found = dynamic_records.find_first(row) with (row.tag == 2);
    if (found.size() != 1 || found[0].value != 20)
      $fatal(1, "dynamic-array aggregate locator failed");
    found[0].value = 88;
    if (dynamic_records[1].value != 20)
      $fatal(1, "dynamic-array aggregate result aliases source");

    found_handles = handles.find_first(item) with (item.value > 0);
    if (found_handles.size() != 1 || found_handles[0] != handles[0])
      $fatal(1, "class locator did not preserve handle identity");

    $display("PASSED");
  end
endmodule
