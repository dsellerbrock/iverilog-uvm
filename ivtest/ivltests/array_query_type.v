module array_query_type;
  typedef logic [16:1] Word;
  typedef logic [3:0][2:1] Packed;
  typedef int IntArray [0:2];
  Word Ram[0:9];
  initial begin
    if ($size(Word) != 16 || $left(Word) != 16 || $right(Word) != 1)
      $fatal(1, "packed type bounds/size");
    if ($low(Word) != 1 || $high(Word) != 16 || $increment(Word) != 1)
      $fatal(1, "packed type low/high/increment");
    if ($dimensions(Word) != 1 || $unpacked_dimensions(Word) != 0)
      $fatal(1, "packed type dimensions");
    if ($size(Packed, 1) != 4 || $size(Packed, 2) != 2
        || $dimensions(Packed) != 2)
      $fatal(1, "multi-dimensional packed type");
    if ($size(IntArray) != 3 || $dimensions(IntArray) != 2
        || $unpacked_dimensions(IntArray) != 1)
      $fatal(1, "unpacked type dimensions");
    if ($left(int) != 31 || $right(int) != 0 || $size(int) != 32)
      $fatal(1, "integer predefined packed dimension");
    if ($size(Ram, 2) != 16)
      $fatal(1, "variable control");
    $display("PASSED");
    $finish;
  end
endmodule
