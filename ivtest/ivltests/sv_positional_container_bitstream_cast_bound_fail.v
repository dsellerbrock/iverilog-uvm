// IEEE 1800-2017/2023 6.24.3: a bit-stream cast whose complete result cannot
// fit a bounded queue target is a size mismatch. Unlike ordinary bounded-
// queue assignment, this cast must not silently truncate the source stream.
typedef bit [7:0] strict_bound_byte_darray_t[];
typedef bit [15:0] strict_bound_word_queue_t[$:1];

module sv_positional_container_bitstream_cast_bound_fail;
  strict_bound_byte_darray_t source;
  strict_bound_word_queue_t result;

  initial begin
    source = new[6];
    source[0] = 8'h12;
    source[1] = 8'h34;
    source[2] = 8'h56;
    source[3] = 8'h78;
    source[4] = 8'h9a;
    source[5] = 8'hbc;
    result = strict_bound_word_queue_t'(source);
    $display("FAILED: oversized bit-stream cast returned %0d bounded words",
             result.size());
  end
endmodule
