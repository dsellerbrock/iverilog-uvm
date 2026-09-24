`include "ivltests/sv_randomize_joint_multiple_dist_fail.v"
`include "ivltests/sv_randomize_joint_ordered_randc_multidist_range_cap_atomic.v"

module probe_multiple;
  range_cap_multi item = new;
  int rc;
  initial begin
    item.srandom(32'h52414e47);
    item.child.srandom(32'h52414348);
    rc = item.randomize();
    $display("multiple rc=%0d value=%0d child=%0d", rc,
             item.value, item.child.value);
    $finish(0);
  end
endmodule

module probe_ordered;
  cap_item item = new;
  int rc;
  initial begin
    item.srandom(32'h52414e47);
    item.child.srandom(32'h52414e43);
    item.small_c.constraint_mode(0);
    rc = item.randomize();
    $display("ordered rc=%0d cycle=%0d early=%0d first=%0d second=%0d child=%0d posts=%0d",
             rc, item.cycle, item.early, item.first,
             item.second, item.child.value, item.posts);
    $finish(0);
  end
endmodule
