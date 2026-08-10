// Iterator arguments are identifiers and are meaningful only with a with
// clause. These malformed calls must not silently ignore their arguments.
module bad_iterator_shape;
  int values[];
  int result[$];
  int item;
  int other;

  initial begin
    result = values.unique(1);
    result = values.unique_index(item, other);
    result = values.unique(item);
    result = values.unique(item[0]) with (item);
    result = values.unique(.iterator(item)) with (item);
    values.unique(item);
  end
endmodule
