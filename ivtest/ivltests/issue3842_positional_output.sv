module issue3842_positional_output;
  class holder;
    int d[][];
    real r[];
    real q[$:1];
  endclass

  holder c;
  int flat[], q[$], empty[$], full[$:1];
  int d[][];
  string text[];
  logic [7:0] four_state[];
  bit [7:0] two_state[];
  logic [79:0] wide_index = 80'h1_0000_0000_0000_0000;
  logic [79:0] x_index = 80'hx;
  logic signed [79:0] negative_index = -1;
  logic signed [65:0] cast_dest[];
  logic signed [7:0] cast_source = -7;
  int index_calls = 0;
  int count, fd;

  function automatic int next_index();
    index_calls++;
    return 1;
  endfunction

  initial begin
    c = new;
    flat = '{1, 2};
    q = '{3, 4};
    full = '{5, 6};
    d = new[2];
    d[0] = '{7, 8};
    d[1] = '{9, 10};
    c.d = new[2];
    c.d[0] = '{11, 12};
    c.d[1] = '{13, 14};
    c.r = '{1.0, 2.0};
    c.q = '{8.0};
    text = '{"old", "keep"};
    four_state = '{8'hcc, 8'h55};
    two_state = '{8'hcc, 8'h55};
    cast_dest = '{66'd4, 66'd5};

    count = $sscanf("17 29 -35 46 3.25 word", "%d %d %d %d %f %s",
                    flat[next_index()], q[0], d[next_index()][0],
                    c.d[1][next_index()], c.r[1], text[0]);
    if (count != 6 || index_calls != 3)
      $fatal(1, "sscanf count=%0d index calls=%0d", count, index_calls);
    if (flat[0] !== 1 || flat[1] !== 17 || q[0] !== 29 || q[1] !== 4)
      $fatal(1, "module elements flat=%p q=%p", flat, q);
    if (d[0][0] !== 7 || d[0][1] !== 8 || d[1][0] !== -35 || d[1][1] !== 10 ||
        c.d[0][0] !== 11 || c.d[0][1] !== 12 || c.d[1][0] !== 13 || c.d[1][1] !== 46)
      $fatal(1, "nested array elements d=%p c.d=%p", d, c.d);
    if (c.r[0] != 1.0 || c.r[1] != 3.25 || text[0] != "word" || text[1] != "keep")
      $fatal(1, "sscanf real or string elements");

    fd = $fopen("work/issue3842_positional_output.txt", "w+");
    if (!fd) $fatal(1, "fopen failed");
    $fdisplay(fd, "39 %s", "from_file");
    if ($rewind(fd) != 0) $fatal(1, "rewind failed");
    count = $fscanf(fd, "%d %s", q[1], text[0]);
    $fclose(fd);
    if (count != 2 || q[0] !== 29 || q[1] !== 39 ||
        text[0] != "from_file" || text[1] != "keep")
      $fatal(1, "fscanf count=%0d q=%p text=%p", count, q, text);

    if (!$value$plusargs("elem=%d", flat[0]) || flat[0] !== -51 || flat[1] !== 17)
      $fatal(1, "integral plusarg");
    if (!$value$plusargs("real=%f", c.q[1]) || c.q.size() != 2 ||
        c.q[0] != 8.0 || c.q[1] != 7.5)
      $fatal(1, "real plusarg append");
    if ($value$plusargs("issue3842_missing=%d", flat[1]) || flat[1] !== 17 ||
        $value$plusargs("issue3842_missing=%d", empty[0]) || empty.size() != 0)
      $fatal(1, "missing plusarg changed a destination");

    count = $sscanf("73 74", "%d %d", empty[0], empty[1]);
    if (count != 2 || empty.size() != 2 || empty[0] !== 73 || empty[1] !== 74)
      $fatal(1, "empty queue append count=%0d empty=%p", count, empty);
    count = $sscanf("75", "%d", empty[$+1]);
    if (count != 1 || empty.size() != 3 || empty[2] !== 75)
      $fatal(1, "queue last-plus-one append");
    count = $sscanf("76", "%d", empty[$]);
    if (count != 1 || empty.size() != 3 || empty[1] !== 74 || empty[2] !== 76)
      $fatal(1, "queue last-element replacement");

    count = $sscanf("70 71 72 73 74", "%d %d %d %d %d",
                    full[2], full[wide_index], full[x_index],
                    full[negative_index], flat[wide_index]);
    if (full.size() != 2 || full[0] !== 5 || full[1] !== 6 ||
        flat.size() != 2 || flat[0] !== -51 || flat[1] !== 17)
      $fatal(1, "invalid index or full queue changed a destination");

    count = $sscanf("1xz01z10 1xz01z10", "%b %b", four_state[1], two_state[1]);
    if (count != 2 || four_state[1] !== 8'b1xz01z10 || two_state[1] !== 8'b10001010 ||
        four_state[0] !== 8'hcc || two_state[0] !== 8'hcc)
      $fatal(1, "four-state or two-state conversion");
    $sformat(text[0], "n=%0d", flat[0]);
    if (text[0] != "n=-51" || text[1] != "keep")
      $fatal(1, "sformat destination");

    if (!$cast(cast_dest[1], cast_source) || cast_dest[1] !== -66'sd7 ||
        cast_dest[0] !== 66'd4)
      $fatal(1, "function cast did not sign-extend the source");
    $cast(cast_dest[1], 7'd121);
    if (cast_dest[1] !== 66'd121 || cast_dest[0] !== 66'd4)
      $fatal(1, "task cast did not zero-extend the source");

    $display("PASSED");
  end
endmodule
