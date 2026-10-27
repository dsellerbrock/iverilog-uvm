// IEEE 1800-2023 7.12.4 exposes the iterator index on the iterator itself,
// not on nested struct members.
module sv_array_index_argument_struct_nested_fail_2023;
  typedef struct { int value; } nested_t;
  typedef struct { nested_t nested; } item_t;
  item_t items[$];
  item_t results[$];

  initial begin
    items.push_back('{nested: '{value: 1}});
    results = items.find(item, position) with
      (item.nested.position == item.position);
  end
endmodule
