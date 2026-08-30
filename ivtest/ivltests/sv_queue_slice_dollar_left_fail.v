// IEEE 1800-2017/2023 7.10.1 permits `$' as this endpoint only when the
// selected receiver is a positional queue, and the other endpoint is integral.
module sv_queue_slice_dollar_left_fail;
  int dynamic_data[];
  int dynamic_result[];
  int associative_data[int];
  int associative_result[int];
  int fixed_data[0:1];
  int fixed_result[0:1];
  logic [7:0] packed_data;
  logic [7:0] packed_result;
  int queue_data[$];
  int queue_result[$];
  real real_bound;

  initial begin
    dynamic_result = dynamic_data[$:1];
    associative_result = associative_data[$:1];
    fixed_result = fixed_data[$:1];
    packed_result = packed_data[$:1];
    queue_result = queue_data[$:real_bound];
  end
endmodule
