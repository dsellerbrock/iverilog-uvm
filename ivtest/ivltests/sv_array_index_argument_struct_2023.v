// IEEE 1800-2023 7.12.4: the optional iterator-index name is available
// while resolving members of an unpacked struct iterator.
module sv_array_index_argument_struct;
  typedef struct { int index; int value; } item_t;
  item_t items[$];
  item_t results[$];

  initial begin
    items.push_back('{index: 10, value: 10});
    items.push_back('{index: 1, value: 20});
    items.push_back('{index: 30, value: 30});

    results = items.find(item, iter_index) with
      (item.index != item.iter_index);
    if (results.size() != 2
        || results[0].index != 10 || results[0].value != 10
        || results[1].index != 30 || results[1].value != 30)
      $fatal(1, "struct iterator index argument failed");
    $display("PASSED");
  end
endmodule
