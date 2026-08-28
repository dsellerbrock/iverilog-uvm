// IEEE 1800-2017/2023 7.6, 13.4.2 and 13.5: non-void function
// output/inout arguments may copy between queue and dynamic-array kinds when
// their element types are equivalent. Copy-back preserves the actual's kind.
module sv_nonvoid_function_container_formal_compat;
  int errors;
  int result;
  logic [7:0] output_queue_actual[$];
  logic [7:0] output_darray_actual[];
  logic [7:0] inout_queue_actual[$];
  logic [7:0] inout_darray_actual[];

  function automatic int build_queue(output logic [7:0] value[$]);
    value.push_back(8'h12);
    value.push_back(8'h34);
    return value.size();
  endfunction

  function automatic int build_darray(output logic [7:0] value[]);
    value = new[2];
    value[0] = 8'h56;
    value[1] = 8'h78;
    return value.size();
  endfunction

  function automatic int append_queue(inout logic [7:0] value[$]);
    int initial_size = value.size();
    value.push_back(8'h9a);
    return initial_size;
  endfunction

  function automatic int grow_darray(inout logic [7:0] value[]);
    int initial_size = value.size();
    value = new[initial_size + 1](value);
    value[initial_size] = 8'hbc;
    return initial_size;
  endfunction

  initial begin
    output_darray_actual = new[1];
    output_darray_actual[0] = 8'haa;
    output_queue_actual.push_back(8'hbb);

    result = build_queue(output_darray_actual);
    if (result != 2 || output_darray_actual.size() != 2
        || output_darray_actual[0] != 8'h12
        || output_darray_actual[1] != 8'h34) begin
      errors++;
      $display("FAILED: queue function output to darray actual");
    end

    result = build_darray(output_queue_actual);
    if (result != 2 || output_queue_actual.size() != 2
        || output_queue_actual[0] != 8'h56
        || output_queue_actual[1] != 8'h78) begin
      errors++;
      $display("FAILED: darray function output to queue actual");
    end

    inout_darray_actual = new[2];
    inout_darray_actual[0] = 8'h21;
    inout_darray_actual[1] = 8'h43;
    result = append_queue(inout_darray_actual);
    if (result != 2 || inout_darray_actual.size() != 3
        || inout_darray_actual[0] != 8'h21
        || inout_darray_actual[2] != 8'h9a) begin
      errors++;
      $display("FAILED: queue function inout with darray actual");
    end

    inout_queue_actual.push_back(8'h65);
    inout_queue_actual.push_back(8'h87);
    result = grow_darray(inout_queue_actual);
    if (result != 2 || inout_queue_actual.size() != 3
        || inout_queue_actual[0] != 8'h65
        || inout_queue_actual[2] != 8'hbc) begin
      errors++;
      $display("FAILED: darray function inout with queue actual");
    end

    // Operations unique to each actual ensure copy-back retained its kind.
    output_darray_actual[output_darray_actual.size()] = 8'hff;
    output_queue_actual.push_back(8'hde);
    inout_darray_actual[inout_darray_actual.size()] = 8'hff;
    inout_queue_actual.push_back(8'hf0);
    if (output_darray_actual.size() != 2 || output_queue_actual.size() != 3
        || output_queue_actual[2] != 8'hde
        || inout_darray_actual.size() != 3 || inout_queue_actual.size() != 4
        || inout_queue_actual[3] != 8'hf0) begin
      errors++;
      $display("FAILED: function copy-back changed an actual container kind");
    end

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
