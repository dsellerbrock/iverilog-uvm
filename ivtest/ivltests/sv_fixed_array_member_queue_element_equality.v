module sv_fixed_array_member_queue_element_equality;
  typedef struct { bit lane[2]; } cfg_t;
  cfg_t a;
  bit arr[2];
  bit [7:0] q[$][3:2];
  bit [7:0] queue_arr[3:2];

  initial begin
    a.lane = '{1, 0};
    arr = a.lane;
    if (!(a.lane == arr)) $fatal(1, "equal array member compares unequal");
    if (a.lane != arr) $fatal(1, "equal array member compares different");
    arr[1] = 1;
    if (a.lane == arr) $fatal(1, "different array member compares equal");

    // Queue insertion of fixed-array elements is not supported yet, so this
    // branch keeps the queue-element comparison's elaboration path covered.
    if (0) $display("%0d", q[0] == queue_arr);
    $display("PASSED");
  end
endmodule
