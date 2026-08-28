// IEEE 1800-2017/2023 6.24.1 and 7.6: an assignment-compatible explicit
// queue cast must retain its target type even when its source is a conditional
// expression. Only the selected arm is copied, and popping the cast temporary
// must not mutate either source dynamic array.
typedef real conditional_cast_darray_t[];
typedef real conditional_cast_queue_t[$];

module sv_container_conditional_explicit_cast;
  int errors;
  bit choose;
  real popped_true;
  real popped_false;
  conditional_cast_darray_t true_source;
  conditional_cast_darray_t false_source;

  initial begin
    true_source = new[2];
    true_source[0] = 1.25;
    true_source[1] = 2.5;
    false_source = new[2];
    false_source[0] = 3.75;
    false_source[1] = 4.5;

    choose = 1'b1;
    popped_true = conditional_cast_queue_t'(
          choose ? true_source : false_source).pop_front();
    choose = 1'b0;
    popped_false = conditional_cast_queue_t'(
          choose ? true_source : false_source).pop_front();

    if (popped_true != 1.25 || popped_false != 3.75) begin
      errors++;
      $display("FAILED: conditional cast selected the wrong arm value");
    end
    if (true_source.size() != 2 || true_source[0] != 1.25
        || true_source[1] != 2.5 || false_source.size() != 2
        || false_source[0] != 3.75 || false_source[1] != 4.5) begin
      errors++;
      $display("FAILED: conditional queue cast aliased a source darray");
    end

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
