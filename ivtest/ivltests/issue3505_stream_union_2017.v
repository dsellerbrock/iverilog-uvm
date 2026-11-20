module issue3505_stream_union;
  typedef union { int first; bit [7:0] second; } word_union_t;
  word_union_t word_union;
  bit [31:0] packed_bits, input_bits;

  initial begin
    word_union.first = 32'h12345678;
    packed_bits = {<<8{word_union}};
    if (packed_bits !== 32'h78563412) $fatal(1, "packed %h", packed_bits);
    input_bits = 32'h89abcdef;
    {>>{word_union}} = input_bits;
    if (word_union.first !== 32'h89abcdef)
      $fatal(1, "unpacked %h", word_union.first);

    $display("PASSED");
  end
endmodule

module issue3505_stream_union_contexts;
  typedef union { int first; bit [7:0] second; } word_union_t;
  typedef union { bit [11:0] first; int second; } short_union_t;
  word_union_t words[2];
  short_union_t short_union;
  union { logic [31:0] first; bit [7:0] second; } logic_union;
  bit [7:0] prefix;
  logic [3:0] suffix;
  byte unsigned bytes[];
  int index;

  initial begin
    // Consume 12 MSBs, then invert the 8-bit slicing of a 12-bit field.
    {<<8{short_union}} = 20'hbca55;
    if (short_union.first !== 12'habc)
      $fatal(1, "inverse slice %h", short_union.first);

    // The union contributes its 12-bit member and casts it to two-state.
    {>>{prefix, short_union, suffix}} = {8'h67, 12'b1xz1_0101_1010, 4'bxz01};
    if (prefix !== 8'h67 || short_union.first !== 12'h95a || suffix !== 4'bxz01)
      $fatal(1, "mixed stream %h %h %b", prefix, short_union.first, suffix);

    {>>{logic_union}} = 32'h1234xz78;
    if (logic_union.first !== 32'h1234xz78)
      $fatal(1, "four-state member %h", logic_union.first);

    bytes = new[5];
    bytes = '{8'h01, 8'h23, 8'h45, 8'h67, 8'h89};
    {<<8{logic_union}} = bytes;
    if (logic_union.first !== 32'h67452301)
      $fatal(1, "dynamic source %h", logic_union.first);

    words[0].first = 32'h76543210;
    index = 1;
    {>>{words[index]}} = 32'hfedcba98;
    if (words[0].first !== 32'h76543210 || words[1].first !== 32'hfedcba98)
      $fatal(1, "indexed receiver %h %h", words[0].first, words[1].first);

    {>>{logic_union}} <= 32'hcafef00d;
    if (logic_union.first !== 32'h67452301)
      $fatal(1, "early NBA store %h", logic_union.first);
    #1;
    if (logic_union.first !== 32'hcafef00d)
      $fatal(1, "missing NBA store %h", logic_union.first);

    $display("PASSED");
  end
endmodule
