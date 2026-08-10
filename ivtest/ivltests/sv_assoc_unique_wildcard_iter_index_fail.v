// IEEE 1800-2017 7.12.4 forbids iterator index querying for a
// wildcard-index associative array, including inside value-returning unique().
module main;
  int values[*];
  int result[$];
  initial begin
    result = values.unique with (item.index);
    result = values.unique(value) with (value.index());
  end
endmodule
