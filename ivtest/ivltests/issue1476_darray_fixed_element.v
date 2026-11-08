// IEEE 1800-2017/2023 7.5.1: a dynamic array whose elements are fixed
// unpacked arrays. new[] allocates default-initialized elements, and the
// fixed dimensions are addressed through the element index chain.
module top;
  int array[][2][3] = new[4];     // the 7.5.1 declaration form
  int d[][2], e[][2];
  logic [3:0] l[][2][2];
  int fails = 0;

  initial begin
    if (array.size() != 4 || array[0][0][0] != 0) fails += 1;
    array[1][1][2] = 7;           // last word of an element
    array[3][0][1] = 9;           // interior word
    if (array[1][1][2] != 7 || array[3][0][1] != 9) fails += 1;
    if (array[1][0][2] != 0 || array[0][1][2] != 0) fails += 1;
    if ($size(array, 2) != 2 || $size(array, 3) != 3) fails += 1;
    if ($unpacked_dimensions(array) != 3) fails += 1;

    d = new[3];
    d[2][1] = 5;
    if (d.size() != 3 || d[2][1] != 5 || d[2][0] != 0) fails += 1;

    l = new[2];                   // 4-state words start at x
    l[1][1][0] = 4'ha;
    if (l[1][1][0] !== 4'ha || l[0][0][0] !== 4'bxxxx) fails += 1;

    d = new[5](d);                // keeps old words, defaults new ones
    if (d.size() != 5 || d[2][1] != 5 || d[4][1] != 0) fails += 1;

    e = d;                        // a copy, not an alias
    e[2][1] = 8;
    if (d[2][1] != 5 || e[2][1] != 8) fails += 1;

    if (fails == 0) $display("PASSED");
    else $display("FAILED %0d", fails);
  end
endmodule
