module p12_07_loops;
  int pass, fail;
  int call_count;
  int a [5:3][0:1];
  int b [1:2][3:4][5:6];

  function automatic int tick();
    call_count++;
    return call_count;
  endfunction

  task automatic check(input bit ok, input string name);
    if (ok) pass++;
    else begin
      fail++;
      $display("FAIL %s", name);
    end
  endtask

  initial begin
    int sum, body, count, index_code, skipped;

    sum = 0;
    for (int i = 0, j = i + 1; i < 3; i++, j++) sum += i * 10 + j;
    check(sum == 36, "for multiple init and step variables");

    body = 0;
    call_count = 0;
    for (int i = 0; i < 3; tick()) begin
      body++;
      i++;
    end
    check(body == 3 && call_count == 3, "for step accepts a function call");

    body = 0;
    for (int i = 0; 1'bx; i++) body++;
    check(body == 0, "for X condition is false");

    body = 0;
    repeat (1'bx) body++;
    check(body == 0, "repeat X count executes zero times");

    body = 0;
    while (1'bx) body++;
    check(body == 0, "while X condition is false");

    body = 0;
    do body++; while (1'b0);
    check(body == 1, "do-while executes before testing");

    count = 0;
    index_code = 0;
    foreach (a[i, j]) begin
      count++;
      index_code = index_code * 10 + (i - 3) * 2 + j;
    end
    check(count == 6 && index_code == 452301,
          "foreach honors descending and ascending bounds");

    skipped = 0;
    foreach (b[i,,k]) skipped++;
    check(skipped == 4, "foreach skips an omitted dimension");

    body = 0;
    forever begin
      body++;
      if (body == 3) break;
    end
    check(body == 3, "break exits forever loop");

    body = 0;
    for (;;) begin
      body++;
      if (body == 2) break;
    end
    check(body == 2, "for loop permits omitted clauses");

    $display("RESULT pass=%0d fail=%0d", pass, fail);
    if (fail != 0) $fatal(1, "loop checks failed");
  end
endmodule
