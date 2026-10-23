// IEEE 1800-2017 does not define the optional array-method index argument.
module sv_array_index_argument_struct;
  typedef struct { int index; int value; } item_t;
  item_t items[$];
  item_t results[$];

  initial begin
    items.push_back('{index: 10, value: 10});
    results = items.find(item, iter_index) with
      (item.index != item.iter_index);
  end
endmodule
