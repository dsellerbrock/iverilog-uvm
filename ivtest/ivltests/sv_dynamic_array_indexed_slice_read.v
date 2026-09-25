// IEEE 1800-2017 7.4.6 / 2023 7.4.5 and both editions 7.6.
// OpenTitan SRAM scrambler shape: a runtime-position, fixed-width slice of
// a one-bit dynamic array is copied into another dynamic array.
module test;
  logic data[];
  logic selected[];
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
    foreach (data[i]) data[i] = (16'hd2b5 >> i) & 1;

    selected = data[base(8) +: 8];
    if (base_calls != 1 || selected.size() != 8)
      $fatal(1, "indexed read base/count: calls=%0d size=%0d",
             base_calls, selected.size());
    foreach (selected[i])
      if (selected[i] !== data[8+i])
        $fatal(1, "indexed read order at %0d", i);

    selected = data[base(11) -: 4];
    if (base_calls != 2 || selected.size() != 4)
      $fatal(1, "indexed descending read base/count");
    foreach (selected[i])
      if (selected[i] !== data[8+i])
        $fatal(1, "indexed descending read order at %0d", i);

    selected = data[14 +: 4];
    if (selected.size() != 4 || selected[0] !== data[14]
        || selected[1] !== data[15] || selected[2] !== 1'bx
        || selected[3] !== 1'bx)
      $fatal(1, "indexed read out-of-range defaults");

    selected = data[-1 +: 2];
    if (selected.size() != 2 || selected[0] !== 1'bx
        || selected[1] !== data[0])
      $fatal(1, "negative-base read defaults");
    selected = data[64'hfffffffffffffffe +: 4];
    if (selected.size() != 4)
      $fatal(1, "wide-base read count");
    foreach (selected[i])
      if (selected[i] !== 1'bx)
        $fatal(1, "wide-base read wrapped at %0d", i);

    wide_base = 65'd8;
    selected = data[wide_base +: 2];
    if (selected.size() != 2 || selected[0] !== data[8]
        || selected[1] !== data[9])
      $fatal(1, "65-bit legal base read");
    max_base = '1;
    selected = data[max_base +: 4];
    foreach (selected[i])
      if (selected[i] !== 1'bx)
        $fatal(1, "127-bit base read wrapped at %0d", i);

    unknown_base = 'x;
    selected = data[unknown_base +: 2];
    if (selected.size() != 2 || selected[0] !== 1'bx
        || selected[1] !== 1'bx)
      $fatal(1, "indexed read unknown-base defaults");

    data = data[base(4) +: 4];
    if (base_calls != 3 || data.size() != 4)
      $fatal(1, "whole-target self-slice base/count");
    foreach (data[i])
      if (data[i] !== ((16'hd2b5 >> (4+i)) & 1))
        $fatal(1, "whole-target self-slice value at %0d", i);
    $display("PASS indexed dynamic-array read");
  end
endmodule
