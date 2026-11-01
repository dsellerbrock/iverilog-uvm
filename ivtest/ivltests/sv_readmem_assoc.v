module sv_readmem_assoc;
  int loaded[int];
  int roundtrip[int];
  logic [7:0] narrow[shortint];
  integer fd;
  integer first;

  initial begin
    fd = $fopen("work/sv_readmem_assoc.hex", "w");
    if (fd == 0) $fatal(1, "could not create input file");
    $fdisplay(fd, "@5");
    $fdisplay(fd, "00000011");
    $fdisplay(fd, "00000022");
    $fclose(fd);

    $readmemh("work/sv_readmem_assoc.hex", loaded);
    if (loaded.size() != 2 || loaded[5] !== 17 || loaded[6] !== 34)
      $fatal(1, "readmemh did not create and load associative entries");

    fd = $fopen("work/sv_readmem_assoc_narrow.hex", "w");
    if (fd == 0) $fatal(1, "could not create narrow-index input file");
    $fdisplay(fd, "@5 11 22");
    $fclose(fd);
    $readmemh("work/sv_readmem_assoc_narrow.hex", narrow);
    if (narrow.size() != 2 || narrow[5] !== 8'h11 || narrow[6] !== 8'h22)
      $fatal(1, "readmemh did not preserve a narrow integral index type");

    $writememh("work/sv_readmem_assoc.out", loaded);
    fd = $fopen("work/sv_readmem_assoc.out", "r");
    if (fd == 0) $fatal(1, "writememh did not create output file");
    first = $fgetc(fd);
    $fclose(fd);
    if (first != "@") $fatal(1, "writememh omitted associative address");

    $readmemh("work/sv_readmem_assoc.out", roundtrip);
    if (roundtrip.size() != 2 || roundtrip[5] !== 17 || roundtrip[6] !== 34)
      $fatal(1, "associative writememh round trip failed");

    $display("PASSED");
    $finish;
  end
endmodule
