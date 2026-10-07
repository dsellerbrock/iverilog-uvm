// IEEE 1800-2023 7.12: the optional index argument renames the iterator's
// index query so an element member named index remains accessible.
class index_argument_item;
  int index;
  int value;

  function new(int i, int v);
    index = i;
    value = v;
  endfunction
endclass

module sv_array_index_argument;
  index_argument_item objects[$];
  index_argument_item first, second, third;
  int values[$];
  int indexes[$];
  int by_name[string];
  string associative_indexes[$];
  int unique_indexes[$];
  int minima[$];
  int maxima[$];
  int total;

  initial begin
    first = new(41, 10);
    second = new(99, 20);
    third = new(41, 30);
    objects.push_back(first);
    objects.push_back(second);
    objects.push_back(third);
    values = '{10, 20, 30};
    by_name["alpha"] = 1;
    by_name["beta"] = 2;

    indexes = objects.find_index(item, position) with
      (item.index == 99 && item.position == 1);
    if (indexes.size() != 1 || indexes[0] != 1)
      $fatal(1, "custom index alias or colliding member failed");

    associative_indexes = by_name.find_index(item, lookup_key) with
      (item == 2 && item.lookup_key == "beta");
    if (associative_indexes.size() != 1
        || associative_indexes[0] != "beta")
      $fatal(1, "associative custom index alias failed");

    total = values.sum(item, position) with (item + item.position);
    if (total != 63)
      $fatal(1, "sum custom index alias failed: %0d", total);

    minima = values.min(item, position) with
      (item - 20 * item.position);
    maxima = values.max(item, position) with
      (item - 20 * item.position);
    if (minima.size() != 1 || minima[0] != 30
        || maxima.size() != 1 || maxima[0] != 10)
      $fatal(1, "min/max custom index alias failed");

    unique_indexes = values.unique_index(item, position) with
      (item % 20 + item.position);
    if (unique_indexes.size() != 3)
      $fatal(1, "unique_index custom alias failed");

    $display("PASSED");
  end
endmodule
