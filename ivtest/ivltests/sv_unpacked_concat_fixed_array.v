// Fixed unpacked arrays are collection items in unpacked-array
// concatenations (IEEE 1800-2017/2023 10.10.1).
module sv_unpacked_concat_fixed_array;
  int A[3] = '{1, 2, 3};
  int B[$] = '{7, 8};
  int C[];

  initial begin
    C = {A};
    if (C.size() != 3 || C[0] != 1 || C[1] != 2 || C[2] != 3)
      $fatal(1, "fixed-array item");

    C = {B, A};
    if (C.size() != 5 || C[0] != 7 || C[1] != 8 || C[2] != 1
        || C[3] != 2 || C[4] != 3)
      $fatal(1, "mixed queue and fixed-array items");

    $display("PASSED");
    $finish(0);
  end
endmodule
