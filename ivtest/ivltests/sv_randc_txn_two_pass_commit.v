// A dynamic foreach forces the size pass followed by the element pass.  One
// successful outer call must consume exactly one tag value; an element-pass
// UNSAT must consume none and must restore the dynamic array as a value.
class randc_txn_two_pass_item;
  randc bit [1:0] tag;
  rand bit [3:0] data[];
  bit reject_elements;

  constraint shape_c { data.size() == 2; }
  constraint element_c {
    foreach (data[i])
      if (reject_elements)
        data[i] != data[i];
      else
        data[i] == i + 1;
  }
endclass

module test;
  initial begin
    randc_txn_two_pass_item item;
    bit [3:0] tag_mask;
    string before_failed_rng;
    bit [1:0] before_failed_tag;
    bit [3:0] before_failed_0;
    bit [3:0] before_failed_1;

    item = new;
    item.srandom(32'h2468_1357);
    for (int cycle = 0; cycle < 6; cycle++) begin
      tag_mask = '0;
      for (int sample = 0; sample < 4; sample++) begin
        item.reject_elements = 0;
        if (item.randomize() !== 1)
          $fatal(1, "satisfiable two-pass randomize failed");
        if (item.data.size() != 2 || item.data[0] !== 1 || item.data[1] !== 2)
          $fatal(1, "two-pass element solution was not committed");
        if (tag_mask[item.tag])
          $fatal(1, "tag repeated inside an aligned four-success cycle");
        tag_mask[item.tag] = 1'b1;

        before_failed_rng = item.get_randstate();
        before_failed_tag = item.tag;
        before_failed_0 = item.data[0];
        before_failed_1 = item.data[1];
        item.reject_elements = 1;
        if (item.randomize() !== 0)
          $fatal(1, "element-pass contradiction did not return zero");
        if (item.tag !== before_failed_tag || item.data.size() != 2
            || item.data[0] !== before_failed_0
            || item.data[1] !== before_failed_1)
          $fatal(1, "element-pass UNSAT changed tag or dynamic-array value");

        // Remove failed-attempt RNG advancement from the oracle.  The next
        // successful call is allowed to differ only if history leaked.
        item.set_randstate(before_failed_rng);
      end
      if (tag_mask !== 4'b1111)
        $fatal(1, "one outer success did not commit exactly one randc value");
    end

    $display("PASSED");
  end
endmodule
