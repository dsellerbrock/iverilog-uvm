// Array locator find_last/find_last_index return only the rightmost match,
// or an empty queue when no element matches (IEEE 1800-2017 7.12.1).
class mem_scb;
  typedef struct {
    int unsigned addr;
    int data;
  } mem_item_t;

  mem_item_t write_item_q[$];

  function void add(input int unsigned addr, input int data);
    mem_item_t item;
    item.addr = addr;
    item.data = data;
    write_item_q.push_back(item);
  endfunction

  function int last_data(input int unsigned addr);
    int found_idx_q[$];
    found_idx_q = write_item_q.find_last_index() with
      (item.addr == addr);
    if (found_idx_q.size())
      return write_item_q[found_idx_q[0]].data;
    return -1;
  endfunction
endclass

module main;
  int values[$];
  int fixed_desc[3:0];
  int fixed_result[1];
  int found[$];
  int indexes[$];
  string words[];
  string strings[$];
  int string_indexes[$];
  mem_scb scb;
  bit failed;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    failed = 1'b0;
    values.push_back(10);
    values.push_back(20);
    values.push_back(30);
    values.push_back(5);

    found = values.find_last() with (item >= 20);
    check("queue find_last", found.size() == 1 && found[0] == 30);
    indexes = values.find_last_index(value) with (value >= 20);
    check("queue find_last_index", indexes.size() == 1 && indexes[0] == 2);
    fixed_result = values.find_last() with (item >= 20);
    check("locator queue result to fixed array", fixed_result[0] == 30);

    words = new[4];
    words[0] = "hello";
    words[1] = "sad";
    words[2] = "hello";
    words[3] = "world";
    strings = words.find_last with (item == "hello");
    check("dynamic string find_last",
          strings.size() == 1 && strings[0] == "hello");
    string_indexes = words.find_last_index() with (item == "hello");
    check("dynamic string find_last_index",
          string_indexes.size() == 1 && string_indexes[0] == 2);

    found = values.find_last with (item == 99);
    indexes = values.find_last_index with (item == 99);
    check("no-match queues", found.size() == 0 && indexes.size() == 0);

    // A descending fixed range is stored in canonical numeric order, which
    // is opposite its declared left-to-right order. First/last must still
    // honor the declared direction.
    fixed_desc[3] = 30;
    fixed_desc[2] = 20;
    fixed_desc[1] = 10;
    fixed_desc[0] = 5;
    found = fixed_desc.find_first with (item >= 20);
    indexes = fixed_desc.find_first_index with (item >= 20);
    check("descending fixed find_first",
          found.size() == 1 && found[0] == 30
          && indexes.size() == 1 && indexes[0] == 3);
    found = fixed_desc.find_last with (item >= 20);
    indexes = fixed_desc.find_last_index with (item >= 20);
    check("descending fixed find_last",
          found.size() == 1 && found[0] == 20
          && indexes.size() == 1 && indexes[0] == 2);

    scb = new;
    scb.add(16, 100);
    scb.add(32, 200);
    scb.add(16, 300);
    check("OpenTitan-shaped latest RAW item", scb.last_data(16) == 300);
    check("OpenTitan-shaped no match", scb.last_data(99) == -1);

    if (failed)
      $fatal(1, "find_last checks failed");
    $display("PASSED");
  end
endmodule
