package scope_helpers;
  localparam bit ZERO = 0;
  let is_zero(value) = value == ZERO;
endpackage

class packet;
  rand bit a[2];
  constraint c {
    foreach (a[i]) a[i] == 0;
    i == 0;
    a.sum() with (int'(item)) == 1;
    item == 0;
  }
  constraint guarded {
    foreach (a[j]) if (j == 0) scope_helpers::is_zero(a[missing_index]);
  }
  extern constraint missing_collection;
endclass

constraint packet::missing_collection {
  foreach (missing_array[k]) k == 0;
}

module top;
  packet o;
  initial o = new;
endmodule
