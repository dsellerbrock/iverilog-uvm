// Extended retained-slice control (focus-only): Icarus preserves the element
// type through q[0:1][0], while Slang 11 rejects chained selects after a range
// select. The array-method iterator must shadow the randc owner property.
class randc_iter_ext_plain_leaf;
  bit [1:0] x;
endclass

class randc_iter_ext_control;
  randc bit [1:0] item;
  rand randc_iter_ext_plain_leaf q[2][2];

  constraint retained_slice_iterator_ok {
    soft ((q[0:1][0].find(item) with (item.x == 0)).size() == 0);
  }
endclass

module test;
  randc_iter_ext_control control;

  initial begin
    control = new;
    $display("PASSED");
  end
endmodule
