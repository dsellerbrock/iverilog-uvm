module sv_readmem_assoc;
  int data[int];
  int copy[int];
  integer fd;
  integer ch;

  initial begin
    fd = $fopen("work/sv_readmem_assoc.hex", "w");
    if (fd == 0) $fatal(1, "could not create readmem input");
    $fdisplay(fd, "@5");
    $fdisplay(fd, "00000011");
    $fdisplay(fd, "00000022");
    $fclose(fd);

    data[5] = -1;
    $readmemh("work/sv_readmem_assoc.hex", data);
    if (data.size() != 2 || data[5] != 17 || data[6] != 34)
      $fatal(1, "$readmemh did not create and update associative entries");

    $writememh("work/sv_readmem_assoc.out", data);
    fd = $fopen("work/sv_readmem_assoc.out", "r");
    if (fd == 0) $fatal(1, "$writememh did not create output");
    ch = $fgetc(fd);
    $fclose(fd);
    if (ch != 64)
      $fatal(1, "$writememh output does not begin with an address");

    $readmemh("work/sv_readmem_assoc.out", copy);
    if (copy.size() != 2 || copy[5] != 17 || copy[6] != 34)
      $fatal(1, "$writememh associative round trip failed");

    $display("ISSUE803_ASSOC_READMEM_PASSED");
    $display("PASSED");
    $finish;
  end
endmodule
