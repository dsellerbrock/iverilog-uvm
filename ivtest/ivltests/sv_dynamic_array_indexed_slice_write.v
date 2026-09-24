// IEEE 1800-2017 7.4.6 / 2023 7.4.5 and both editions 7.6.
// A slice l-value writes selected dynamic-array elements, never resizes it.
module test;
  logic data[];
  logic replacement[];
  logic tail[];
  logic saved[];
  logic fixed_source[0:3];
  logic reverse_source[3:0];
  logic [3:0] unknown_base;
  logic [64:0] wide_base;
  logic [126:0] max_base;
  int base_calls;

  function automatic int base(input int value);
    base_calls++;
    return value;
  endfunction

  initial begin
    data = new[16];
    replacement = new[8];
    tail = new[4];
    foreach (data[i]) data[i] = (16'hd2b5 >> i) & 1;
    foreach (replacement[i]) replacement[i] = (8'h96 >> i) & 1;
    foreach (tail[i]) tail[i] = (4'h3 >> i) & 1;
    foreach (fixed_source[i]) fixed_source[i] = (4'h5 >> i) & 1;
    foreach (reverse_source[i]) reverse_source[i] = (4'h9 >> i) & 1;

    data[base(8) +: 8] = replacement;
    if (base_calls != 1 || data.size() != 16)
      $fatal(1, "indexed write base/count");
    for (int i = 0; i < 8; i++) begin
      if (data[i] !== ((16'hd2b5 >> i) & 1))
        $fatal(1, "indexed write changed prefix at %0d", i);
      if (data[8+i] !== replacement[i])
        $fatal(1, "indexed write order at %0d", i);
    end

    data[base(14) +: 4] = tail;
    if (base_calls != 2 || data.size() != 16)
      $fatal(1, "out-of-range write base/count");
    if (data[14] !== tail[0] || data[15] !== tail[1])
      $fatal(1, "valid words of out-of-range write");
    for (int i = 0; i < 8; i++)
      if (data[i] !== ((16'hd2b5 >> i) & 1))
        $fatal(1, "out-of-range write changed prefix at %0d", i);

    saved = data;
    unknown_base = 'x;
    data[unknown_base +: 4] = tail;
    if (data.size() != 16)
      $fatal(1, "unknown-base write changed size");
    foreach (data[i])
      if (data[i] !== saved[i])
        $fatal(1, "unknown-base write changed word %0d", i);

    data[base(5) -: 4] = fixed_source;
    if (base_calls != 3 || data.size() != 16)
      $fatal(1, "descending fixed-source write base/count");
    foreach (fixed_source[i])
      if (data[2+i] !== fixed_source[i])
        $fatal(1, "descending fixed-source write order at %0d", i);

    data[9 +: 4] = reverse_source;
    for (int i = 0; i < 4; i++)
      if (data[9+i] !== reverse_source[3-i])
        $fatal(1, "reverse-range source order at %0d", i);

    saved = data;
    data[64'hfffffffffffffffe +: 4] = fixed_source;
    if (data.size() != 16)
      $fatal(1, "wide-base write changed size");
    foreach (data[i])
      if (data[i] !== saved[i])
        $fatal(1, "wide-base write wrapped at %0d", i);

    wide_base = 65'd4;
    data[wide_base +: 4] = fixed_source;
    foreach (fixed_source[i])
      if (data[4+i] !== fixed_source[i])
        $fatal(1, "65-bit legal base write at %0d", i);
    saved = data;
    max_base = '1;
    data[max_base +: 4] = fixed_source;
    foreach (data[i])
      if (data[i] !== saved[i])
        $fatal(1, "127-bit base write wrapped at %0d", i);
    $display("PASS indexed dynamic-array write");
  end
endmodule
