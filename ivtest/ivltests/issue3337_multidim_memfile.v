// Issue #3337: the system tasks keep addressing a multidimensional memory
// as flat, row-major, each dimension from low to high address (IEEE
// 1800-2023 21.4.3), now that VPI selects its words by dimension.
module top;
  logic [7:0] m [1:0][4:6];
  logic [7:0] r [1:0][4:6];
  integer fd, i, j, failures = 0;
  string s;

  initial begin
    for (i = 0; i < 2; i += 1)
      for (j = 4; j <= 6; j += 1)
        m[i][j] = 8'h10 * i + j;
    $writememh("work/issue3337_memfile.out", m);
    // Row-major from the low address: m[0][4], m[0][5], ..., m[1][6].
    fd = $fopen("work/issue3337_memfile.out", "r");
    for (i = 0; i < 6; ) begin
      if ($fgets(s, fd) == 0) break;
      if (s[0] == "/") continue;
      if (s.substr(0, 1) != $sformatf("%02h", 8'h10 * (i / 3) + 4 + (i % 3))) begin
        $display("FAILED: line %0d is %s", i, s);
        failures += 1;
      end
      i += 1;
    end
    $fclose(fd);
    $readmemh("work/issue3337_memfile.out", r);
    for (i = 0; i < 2; i += 1)
      for (j = 4; j <= 6; j += 1)
        if (r[i][j] !== m[i][j]) begin
          $display("FAILED: r[%0d][%0d] = %h, want %h", i, j, r[i][j], m[i][j]);
          failures += 1;
        end
    if (failures == 0) $display("PASSED");
  end
endmodule
