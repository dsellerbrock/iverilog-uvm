// IEEE 1800-2017/2023 13.3.2 and 13.5: an automatic task output formal is
// initialized to its type's default and copied out even when the task body
// never writes it. The untouched defaults therefore replace preexisting
// queue and dynamic-array actual values with empty containers.
module sv_task_output_container_untouched_default;
  int errors;
  int actual_q[$];
  int actual_d[];

  task automatic leave_outputs_untouched(output int q[$], output int d[]);
  endtask

  initial begin
    actual_q = '{11, 13};
    actual_d = new[2];
    actual_d[0] = 17;
    actual_d[1] = 19;

    leave_outputs_untouched(actual_q, actual_d);

    if (actual_q.size() != 0) begin
      errors++;
      $display("FAILED: untouched queue output retained %0d elements",
               actual_q.size());
    end
    if (actual_d.size() != 0) begin
      errors++;
      $display("FAILED: untouched dynamic-array output retained %0d elements",
               actual_d.size());
    end

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d untouched output mismatches", errors);
  end
endmodule
