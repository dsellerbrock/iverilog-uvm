// Extended differential negative (focus-only, not in the strict main lists):
// multidimensional array-method iterators carry the selected element type
// through nesting, partial indices, retained slices, static scoped storage,
// and selected/locator-result iterators. Slang 11 misses these indirect randc
// references (and rejects the retained-slice grammar); Icarus diagnoses each
// supported soft construct exactly once.
class randc_iter_bad_leaf;
  randc bit [1:0] x;

  function randc_iter_bad_leaf id();
    return this;
  endfunction
endclass

class randc_iter_bad_static_box;
  static randc_iter_bad_leaf q[2][2];
endclass

class randc_iter_bad_owner;
  bit [1:0] i;
  bit [1:0] j;
  bit [1:0] item;
  rand randc_iter_bad_leaf q2[2][2];
  rand randc_iter_bad_leaf q3[2][2][2];

  constraint nested_iterator_bad {
    soft ((q2.find() with
      ((item.find(j) with (j.x == 0)).size() > 0)).size() == 0);
  }
  constraint selected_nested_iterator_bad {
    soft ((q3[0].find(i) with
      ((i.find(j) with (j.x == 0)).size() > 0)).size() == 0);
  }
  constraint retained_slice_iterator_bad {
    soft ((q2[0:1][0].find(item) with (item.x == 0)).size() == 0);
  }
  constraint scoped_static_partial_bad {
    soft ((randc_iter_bad_static_box::q[0].find(item) with
      (item.x == 0)).size() == 0);
  }
  constraint selected_outer_iterator_bad {
    soft ((q2.find() with (item[0].id().x == 0)).size() == 0);
  }
  constraint chained_locator_iterator_bad {
    soft (((q2[0].find(i) with (1)).find(j) with
      (j.x == 0)).size() == 0);
  }
endclass

module test;
  randc_iter_bad_owner owner;
endmodule
