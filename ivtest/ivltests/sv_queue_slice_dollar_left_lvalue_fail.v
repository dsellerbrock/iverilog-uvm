// A left-`$' queue slice is a legal variable_lvalue under IEEE
// 1800-2017/2023 A.8.5 and 7.6. Keep the current implementation boundary
// explicit until the l-value ABI carries both dynamic slice endpoints.
module sv_queue_slice_dollar_left_lvalue_fail;
  class queue_box;
    int values[$];
  endclass

  class static_queue_box;
    static int values[$];
  endclass

  int q[$];
  int hi;
  queue_box box;
  queue_box boxes[$];

  initial begin
    q = {1, 2, 3};
    hi = 3;
    box = new;
    box.values = q;
    boxes = {box};
    static_queue_box::values = q;
    q[$:hi] = {4};
    boxes[0].values[$:hi] = {5};
    static_queue_box::values[$:hi] = {6};
  end
endmodule
