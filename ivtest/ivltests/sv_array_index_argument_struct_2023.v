// IEEE 1800-2023 7.12.4: the optional iterator-index name is visible
// while resolving members of an unpacked struct iterator.
module sv_array_index_argument_struct;
  typedef struct { int index; int value; } item_t;
  item_t items[$];
  item_t results[$];
  item_t nested_results[$];

  typedef struct { int iter_index; int value; } named_item_t;
  named_item_t named_items[$];
  named_item_t named_results[$];

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

    named_items.push_back('{iter_index: 9, value: 40});
    named_items.push_back('{iter_index: 8, value: 50});
    named_results = named_items.find(item, iter_index) with
      (item.iter_index == 9);
    if (named_results.size() != 1 || named_results[0].value != 40)
      $fatal(1, "same-named struct member lookup failed");

    nested_results = items.find(outer_item, outer_pos) with
      ((items.find(inner_item, inner_pos) with
        (inner_item.inner_pos == outer_item.outer_pos)).size() > 0);
    if (nested_results.size() != 3)
      $fatal(1, "nested iterator aliases leaked or lost their context");

    $display("PASSED");
  end
endmodule
