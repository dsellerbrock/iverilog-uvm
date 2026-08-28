// IEEE 1800-2017/2023 6.24.3: a dynamically sized bit-stream cast must
// report a run-time size mismatch when the source bit count cannot be divided
// into complete destination elements. It must not zero-fill a partial word.
typedef bit [7:0] strict_size_byte_queue_t[$];
typedef bit [15:0] strict_size_word_darray_t[];

module sv_positional_container_bitstream_cast_size_fail;
  strict_size_byte_queue_t source;
  strict_size_word_darray_t result;

  initial begin
    source.push_back(8'h12);
    source.push_back(8'h34);
    source.push_back(8'h56);
    result = strict_size_word_darray_t'(source);
    $display("FAILED: nondivisible bit-stream cast returned %0d words",
             result.size());
  end
endmodule
