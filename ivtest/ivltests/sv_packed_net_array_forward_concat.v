module sv_packed_net_array_forward_concat;
  logic [7:0] source_word;
  wire [1:0][3:0] forward_words [0:0];
  wire [1:0][3:0] direct_words [0:0];
  wire [1:0][3:0] undriven_words [0:0];
  wire [7:0] single_packed_words [0:0];
  logic [1:0][3:0] variable_words [0:0];

  // The concatenation driver is emitted after packed metadata for the net
  // array, so its first word attaches only during VVP link resolution.
  assign forward_words[0] = {source_word[3:0], source_word[7:4]};
  assign direct_words[0] = source_word;
  assign single_packed_words[0] = {source_word[3:0], source_word[7:4]};

  initial begin
    source_word = 8'h5a;
    variable_words[0] = {source_word[3:0], source_word[7:4]};
    #1;
    if (forward_words[0] !== 8'ha5 || direct_words[0] !== 8'h5a ||
        undriven_words[0] !== 8'hzz ||
        single_packed_words[0] !== 8'ha5 || variable_words[0] !== 8'ha5)
      $fatal(1, "packed net-array word mismatch");
    $display("PASSED");
    $finish(0);
  end
endmodule
