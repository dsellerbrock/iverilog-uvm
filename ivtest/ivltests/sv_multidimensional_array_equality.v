module sv_multidimensional_array_equality;
  int left [1:0][2:4];
  int right [1:0][2:4];
  int opposite [0:1][4:2];
  int outer_reversed [0:1][2:4];
  int inner_reversed [1:0][4:2];

  initial begin
    foreach (left[i,j]) begin
      left[i][j] = i * 10 + j;
      right[i][j] = i * 10 + j;
    end
    foreach (opposite[i,j])
      opposite[i][j] = (1 - i) * 10 + (4 - j) + 2;
    foreach (outer_reversed[i,j])
      outer_reversed[i][j] = (1 - i) * 10 + j;
    foreach (inner_reversed[i,j])
      inner_reversed[i][j] = i * 10 + (6 - j);

    if (!(left == right)) $fatal(1, "equal arrays compare unequal");
    if (left != right) $fatal(1, "equal arrays compare different");
    if (!(left === right)) $fatal(1, "case-equal arrays compare unequal");
    if (left !== right) $fatal(1, "case-equal arrays compare different");
    if (!(left == opposite)) $fatal(1, "opposite-direction arrays compare unequal");
    if (!(left == outer_reversed)) $fatal(1, "outer-reversed arrays compare unequal");
    if (!(left == inner_reversed)) $fatal(1, "inner-reversed arrays compare unequal");

    right[0][4] = -1;
    if (left == right) $fatal(1, "different arrays compare equal");
    if (!(left != right)) $fatal(1, "different arrays compare equal with !=");
    if (left === right) $fatal(1, "different arrays compare case-equal");
    if (!(left !== right)) $fatal(1, "different arrays compare case-equal with !==");

    $display("PASSED");
  end
endmodule
