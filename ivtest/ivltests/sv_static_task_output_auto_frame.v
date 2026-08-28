// IEEE 1800-2017/2023 13.3.1, 13.3.2 and 13.5: an explicitly automatic
// local gives an otherwise static task a per-call frame, but does not make
// the task's output formals automatic. Static output storage still persists.
module sv_static_task_output_auto_frame;
  int errors;
  int frame_sum;
  int seen_size;
  int first_actual[$];
  int second_actual[$];

  task static retain_output(output int value[$], output int initial_size,
                            input bit replace_value);
    automatic int frame_marker = replace_value ? 17 : 99;

    frame_sum += frame_marker;
    initial_size = value.size();
    if (replace_value) begin
      value.delete();
      value.push_back(frame_marker);
    end
  endtask

  initial begin
    first_actual.push_back(1);
    retain_output(first_actual, seen_size, 1'b1);
    if (seen_size != 0 || first_actual.size() != 1
        || first_actual[0] != 17) begin
      errors++;
      $display("FAILED: first static output call saw caller storage");
    end

    // Caller mutation must not alias the retained formal container.
    first_actual[0] = 23;
    second_actual.push_back(31);
    retain_output(second_actual, seen_size, 1'b0);
    if (seen_size != 1 || first_actual.size() != 1
        || first_actual[0] != 23 || second_actual.size() != 1
        || second_actual[0] != 17) begin
      errors++;
      $display("FAILED: framed static task lost retained output storage");
    end

    if (frame_sum != 116) begin
      errors++;
      $display("FAILED: automatic frame locals summed to %0d", frame_sum);
    end

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
