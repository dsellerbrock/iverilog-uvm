class rv_dm_words_worker;
  task body();
    bit [31:0] words[8];
    bit seen[8];
    for (int trial = 0; trial < 8; ++trial) begin
      if (!std::randomize(words)) $fatal(1, "class-local randomize failed");
      for (int i = 0; i < 8; ++i) seen[i] |= words[i] != 0;
    end
    for (int i = 0; i < 8; ++i)
      if (!seen[i]) $fatal(1, "class-local word %0d never changed", i);
  endtask
endclass

module sv_std_randomize_fixed_array;
  bit [31:0] words[8];
  bit seen[8];
  bit [15:0] offset_words[5:12];
  bit seen_offset[5:12];
  bit [7:0] extra;

  initial begin
    rv_dm_words_worker worker;
    worker = new;
    for (int trial = 0; trial < 8; ++trial) begin
      if (!std::randomize(words, extra)) $fatal(1, "module array randomize failed");
      std::randomize(offset_words);
      for (int i = 0; i < 8; ++i) seen[i] |= words[i] != 0;
      for (int i = 5; i <= 12; ++i)
        seen_offset[i] |= offset_words[i] != 0;
    end
    for (int i = 0; i < 8; ++i)
      if (!seen[i]) $fatal(1, "module word %0d never changed", i);
    for (int i = 5; i <= 12; ++i)
      if (!seen_offset[i]) $fatal(1, "offset word %0d never changed", i);
    worker.body();
    $display("PASSED");
    $finish(0);
  end
endmodule
