// IEEE 1800-2017/2023 6.24.1 and 6.24.3: when ordinary assignment
// compatibility does not apply, explicit casting remains legal between
// bit-stream types. Queue/dynamic-array element types may therefore have
// different widths when the complete source stream divides the target
// element width exactly.
typedef bit [7:0] byte_queue_t[$];
typedef bit [15:0] word_darray_t[];
typedef bit [15:0] huge_bound_word_queue_t[$:4294967296];

module sv_positional_container_bitstream_cast;
  int errors;
  byte_queue_t source_bytes;
  byte_queue_t roundtrip_bytes;
  word_darray_t cast_words;
  bit [15:0] huge_bound_first;

  initial begin
    source_bytes.push_back(8'h12);
    source_bytes.push_back(8'h34);
    source_bytes.push_back(8'h56);
    source_bytes.push_back(8'h78);

    cast_words = word_darray_t'(source_bytes);
    if (cast_words.size() != 2
        || cast_words[0] != 16'h1234
        || cast_words[1] != 16'h5678) begin
      errors++;
      $display("FAILED: byte queue did not cast to two-word darray");
    end

    roundtrip_bytes = byte_queue_t'(cast_words);
    if (roundtrip_bytes.size() != 4
        || roundtrip_bytes[0] != 8'h12
        || roundtrip_bytes[1] != 8'h34
        || roundtrip_bytes[2] != 8'h56
        || roundtrip_bytes[3] != 8'h78) begin
      errors++;
      $display("FAILED: word darray did not cast back to byte queue");
    end

    // A bound above UINT_MAX must not wrap through the runtime queue API.
    source_bytes.push_back(8'h9a);
    source_bytes.push_back(8'hbc);
    if (huge_bound_word_queue_t'(source_bytes).size() != 3) begin
      errors++;
      $display("FAILED: 64-bit bounded queue cast wrapped its capacity");
    end
    huge_bound_first = huge_bound_word_queue_t'(source_bytes).pop_front();
    if (huge_bound_first != 16'h1234) begin
      errors++;
      $display("FAILED: 64-bit bounded queue cast lost its first element");
    end

    // Prove the two cast temporaries have independent storage and retain
    // their target container kinds.
    source_bytes[0] = 8'haa;
    cast_words[0] = 16'hbcde;
    roundtrip_bytes.push_back(8'hf0);
    if (source_bytes[0] != 8'haa || cast_words[0] != 16'hbcde
        || roundtrip_bytes.size() != 5
        || roundtrip_bytes[0] != 8'h12
        || roundtrip_bytes[4] != 8'hf0) begin
      errors++;
      $display("FAILED: bit-stream cast temporary identity or kind");
    end

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
