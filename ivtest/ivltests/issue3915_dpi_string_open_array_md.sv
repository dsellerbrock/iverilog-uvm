module issue3915_dpi_string_open_array_md;
  import "DPI-C" function int issue3915_read(input string a[][]);
  import "DPI-C" function int issue3915_fill(output string a[][]);
  import "DPI-C" function int issue3915_swap(inout string a[][]);
  import "DPI-C" function int issue3915_rank3(input string a[][][]);
  import "DPI-C" function int issue3915_rank4(input string a[][][][]);
  import "DPI-C" function int issue3915_empty(input string a[][], input int rows);

  string matrix[2:1][-4:-2];
  string cube[6:6][2:3][-1:-2];
  string tensor[4:3][5:6][-7:-6][9:8];
  string empty[][];

  initial begin
    matrix[2][-4] = "a";
    matrix[2][-3] = "bb";
    matrix[2][-2] = "ccc";
    matrix[1][-4] = "dddd";
    matrix[1][-3] = "";
    matrix[1][-2] = "ffffff";
    if (!issue3915_read(matrix)) $fatal(1, "2-D read or bounds");

    if (!issue3915_fill(matrix)) $fatal(1, "2-D output element access");
    if (matrix[2][-4] != "alpha" || matrix[2][-3] != "bravo" ||
        matrix[2][-2] != "charlie" || matrix[1][-4] != "delta" ||
        matrix[1][-3] != "echo" || matrix[1][-2] != "foxtrot")
      $fatal(1, "2-D output copyback");

    if (!issue3915_swap(matrix)) $fatal(1, "2-D inout element access");
    if (matrix[2][-4] != "foxtrot" || matrix[2][-3] != "bravo" ||
        matrix[2][-2] != "charlie" || matrix[1][-4] != "delta" ||
        matrix[1][-3] != "echo" || matrix[1][-2] != "alpha")
      $fatal(1, "2-D inout copyback");

    cube[6][3][-2] = "third";
    if (!issue3915_rank3(cube)) $fatal(1, "3-D specialized read");
    tensor[3][6][-7][9] = "nine";
    tensor[3][6][-7][8] = "eight";
    if (!issue3915_rank4(tensor)) $fatal(1, "4-D variadic read or bounds");

    if (!issue3915_empty(empty, 0)) $fatal(1, "unallocated actual");
    empty = new[0];
    if (!issue3915_empty(empty, 0)) $fatal(1, "empty actual");
    empty = new[1];
    empty[0] = new[0];
    if (!issue3915_empty(empty, 1)) $fatal(1, "empty leaf");
    $display("PASSED");
  end
endmodule
