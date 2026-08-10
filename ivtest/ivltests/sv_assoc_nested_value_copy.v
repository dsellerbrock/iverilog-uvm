// Associative arrays copy nested container elements by value while class
// elements retain handle identity.
module sv_assoc_nested_value_copy;
  class C;
    int value;
  endclass

  typedef int inner_assoc_t[string];
  typedef int int_queue_t[$];
  typedef int int_darray_t[];
  typedef inner_assoc_t outer_assoc_t[int];
  typedef int_queue_t outer_queue_t[int];
  typedef int_darray_t outer_darray_t[int];
  typedef C outer_class_t[int];
  typedef struct { inner_assoc_t values; } struct_assoc_t;

  outer_assoc_t assoc_src, assoc_dst;
  outer_queue_t queue_src, queue_dst;
  outer_darray_t darray_src, darray_dst;
  outer_class_t class_src, class_dst;
  struct_assoc_t struct_src, struct_dst;

  task automatic mutate_input(input outer_assoc_t value);
    value[1]["a"] = 70;
  endtask

  initial begin
    assoc_src[1]["a"] = 10;
    assoc_dst = assoc_src;
    assoc_dst[1]["a"] = 20;
    if (assoc_src[1]["a"] != 10 || assoc_dst[1]["a"] != 20)
      $fatal(1, "FAILED -- nested associative value copy");
    mutate_input(assoc_src);
    if (assoc_src[1]["a"] != 10)
      $fatal(1, "FAILED -- nested associative input copy");

    queue_src[1].push_back(30);
    queue_dst = queue_src;
    queue_dst[1][0] = 40;
    if (queue_src[1][0] != 30 || queue_dst[1][0] != 40)
      $fatal(1, "FAILED -- nested queue value copy");

    darray_src[1] = new[1];
    darray_src[1][0] = 50;
    darray_dst = darray_src;
    darray_dst[1][0] = 60;
    if (darray_src[1][0] != 50 || darray_dst[1][0] != 60)
      $fatal(1, "FAILED -- nested dynamic-array value copy");

    class_src[1] = new;
    class_src[1].value = 80;
    class_dst = class_src;
    class_dst[1].value = 90;
    if (class_src[1].value != 90)
      $fatal(1, "FAILED -- class element handle identity");

    struct_src.values["a"] = 100;
    struct_dst = struct_assoc_t'(struct_src);
    struct_dst.values["a"] = 110;
    if (struct_src.values["a"] != 100 ||
        struct_dst.values["a"] != 110)
      $fatal(1, "FAILED -- same-type struct cast nested value copy");

    $display("PASSED");
  end
endmodule
