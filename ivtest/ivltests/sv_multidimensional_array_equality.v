module sv_multidimensional_array_equality;
  int left [1:0][2:4];
  int right [1:0][2:4];

  initial begin
    foreach (left[i,j]) begin
      left[i][j] = i * 10 + j;
      right[i][j] = i * 10 + j;
    end

    if (!(left == right)) $fatal(1, "equal arrays compare unequal");
    if (left != right) $fatal(1, "equal arrays compare different");
    if (!(left === right)) $fatal(1, "case-equal arrays compare unequal");
    if (left !== right) $fatal(1, "case-equal arrays compare different");

    right[0][4] = -1;
    if (left == right) $fatal(1, "different arrays compare equal");
    if (!(left != right)) $fatal(1, "different arrays compare equal with !=");
    if (left === right) $fatal(1, "different arrays compare case-equal");
    if (!(left !== right)) $fatal(1, "different arrays compare case-equal with !==");

    $display("PASSED");
  end
endmodule
