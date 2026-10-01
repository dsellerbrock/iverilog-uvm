// Selecting a missing associative key creates its fixed child for foreach.
module test;
  typedef enum { PartData, PartInfo } part_e;
  int tgt[part_e][4];
  part_e p = PartData;
  initial begin
    foreach (tgt[p][i]) tgt[p][i] = i;
    if (!tgt.exists(PartData) || tgt.exists(PartInfo))
      $fatal(1, "selected key existence is wrong");
    for (int i = 0; i < 4; i++)
      if (tgt[PartData][i] != i) $fatal(1, "child element %0d", i);
    $display("PASSED");
  end
endmodule
