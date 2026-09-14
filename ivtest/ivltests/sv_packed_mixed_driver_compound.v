module packed_mixed_driver_compound_case #(parameter int N = 2);
  logic [N-1:0][7:0] static_words;
  logic [7:0] dynamic_word;
  logic [7:0] unknown_word;
  logic [7:0] source = 8'h20;
  int index_calls;

  function automatic int select_zero();
    index_calls++;
    return 0;
  endfunction

  always_comb begin
    static_words[0] = source;
    static_words[0] ^= 8'h0f;
    index_calls = 0;
    dynamic_word = 8'h20;
    dynamic_word[select_zero() +: 4] += 4'h3;
    unknown_word = 8'h45;
    unknown_word[1'bx +: 4] ^= 4'hf;
  end

  for (genvar i = 1; i < N; i++) begin
    assign static_words[i] = static_words[i-1] + 1'b1;
  end

  initial begin
    #1;
    if (index_calls != 1)
      $fatal(1, "dynamic index evaluated %0d times", index_calls);
    for (int i = 0; i < N; i++) begin
      if (static_words[i] !== 8'h2f + i)
        $fatal(1, "static word %0d wrong: %h", i, static_words[i]);
    end
    if (dynamic_word !== 8'h23)
      $fatal(1, "dynamic part update wrong: %h", dynamic_word);
    if (unknown_word !== 8'h45)
      $fatal(1, "unknown index changed the word: %h", unknown_word);
    source = 8'h30;
    #1;
    for (int i = 0; i < N; i++)
      if (static_words[i] !== 8'h3f + i)
        $fatal(1, "updated static word %0d wrong: %h", i, static_words[i]);
  end
endmodule

module sv_packed_mixed_driver_compound;
  packed_mixed_driver_compound_case #(.N(2)) n2();
  packed_mixed_driver_compound_case #(.N(6)) n6();

  initial begin
    #3;
    $display("PASSED");
  end
endmodule
