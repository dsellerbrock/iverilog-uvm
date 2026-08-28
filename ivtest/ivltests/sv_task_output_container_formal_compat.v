// IEEE 1800-2017/2023 7.6 and 13.5: queue and dynamic-array output
// arguments may copy across container kinds when their element types are
// equivalent. The caller's destination kind is preserved by copy-out.
module sv_task_output_container_formal_compat;
  int errors;
  logic [7:0] queue_actual[$];
  logic [7:0] darray_actual[];

  task automatic build_queue(output logic [7:0] value[$]);
    value.push_back(8'h12);
    value.push_back(8'h34);
  endtask

  task automatic build_darray(output logic [7:0] value[]);
    value = new[2];
    value[0] = 8'h56;
    value[1] = 8'h78;
  endtask

  initial begin
    darray_actual = new[1];
    darray_actual[0] = 8'haa;
    queue_actual.push_back(8'hbb);

    build_queue(darray_actual);
    build_darray(queue_actual);

    if (darray_actual.size() != 2
        || darray_actual[0] != 8'h12
        || darray_actual[1] != 8'h34) begin
      errors++;
      $display("FAILED: queue formal did not copy to darray actual");
    end
    if (queue_actual.size() != 2
        || queue_actual[0] != 8'h56
        || queue_actual[1] != 8'h78) begin
      errors++;
      $display("FAILED: darray formal did not copy to queue actual");
    end

    // Exercise operations unique to each destination container kind.
    darray_actual = new[3](darray_actual);
    darray_actual[2] = 8'h9a;
    queue_actual.push_back(8'hbc);
    if (darray_actual.size() != 3 || darray_actual[2] != 8'h9a
        || queue_actual.size() != 3 || queue_actual[2] != 8'hbc) begin
      errors++;
      $display("FAILED: output copy-out changed the actual container kind");
    end

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
