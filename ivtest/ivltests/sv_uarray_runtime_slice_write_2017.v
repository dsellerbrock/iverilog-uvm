module sv_uarray_runtime_slice_write;
  int a[0:3], b[0:3], descending[12:9], pair[9:8], shifted[127:130];
  real real_dst[0:3], real_src[2:1];
  string strings[0:2], words[1:0];
  logic logic_dst[9:10], states[0:1];
  integer i, source_base;
  logic signed [129:0] wide;
  byte unsigned unsigned_base;
  int selector_calls, rhs_calls;

  function automatic int select_once(input int index);
    selector_calls++;
    return index;
  endfunction

  function automatic int get_value(input int value);
    rhs_calls++;
    return value;
  endfunction

  function automatic int schedule_word(input int index);
    b[index] <= 99;
    return 22;
  endfunction

  task automatic check_b(input string context_name, input int v0, v1, v2, v3);
    if (b[0] !== v0 || b[1] !== v1 || b[2] !== v2 || b[3] !== v3)
      $fatal(1, "%s: b = {%0d,%0d,%0d,%0d}", context_name,
             b[0], b[1], b[2], b[3]);
  endtask

  task automatic check_local;
    int local_words[-2:1];
    int base;
    local_words = '{default:0};
    base = -1;
    local_words[base +: 2] = a[2:3];
    if (local_words[-2] !== 0 || local_words[-1] !== 3 ||
        local_words[0] !== 4 || local_words[1] !== 0)
      $fatal(1, "automatic destination");
  endtask

  initial begin
    selector_calls = 0;
    rhs_calls = 0;
    a[2] = 3;
    a[3] = 4;
    b = '{5, 6, 7, 8};
    i = 1;
    b[i +: 2] = a[2:3];
    check_b("fixed source", 5, 3, 4, 8);

    descending = '{5, 6, 7, 8};
    i = 11;
    descending[select_once(i) -: 2] = a[2:3];
    if (selector_calls != 1 || descending[12] !== 5 ||
        descending[11] !== 3 || descending[10] !== 4 || descending[9] !== 8)
      $fatal(1, "descending target and ascending source");
    descending[i -: 2] = '{21, 22};
    if (descending[11] !== 21 || descending[10] !== 22)
      $fatal(1, "descending positional pattern");
    descending[i -: 2] = '{default:23};
    if (descending[11] !== 23 || descending[10] !== 23)
      $fatal(1, "default pattern");

    i = 1;
    b[i +: 3] = b[0:2];
    check_b("overlapping self-copy", 5, 5, 3, 4);
    b[i +: 2] = '{b[2], b[1]};
    check_b("overlapping pattern", 5, 3, 5, 4);

    pair = '{31, 32};
    i = -1;
    b[i +: 2] = pair;
    check_b("low overrun", 32, 3, 5, 4);
    i = 3;
    b[i +: 2] = '{41, 42};
    check_b("high overrun", 32, 3, 5, 41);

    i = 'x;
    b[i +: 2] = '{get_value(1), get_value(2)};
    i = 'z;
    b[i -: 2] = '{get_value(3), get_value(4)};
    i = -4;
    b[select_once(i) +: 2] = '{get_value(5), get_value(6)};
    wide = (130'sd1 << 128) | 130'sd1;
    b[wide +: 2] = '{get_value(7), get_value(8)};
    if (selector_calls != 2 || rhs_calls != 8)
      $fatal(1, "invalid selectors must still evaluate the full RHS");
    check_b("X, Z, wholly invalid and wide selectors", 32, 3, 5, 41);

    states = '{1'bx, 1'bz};
    logic_dst = '{1'b0, 1'b1};
    wide = 8;
    logic_dst[wide +: 2] = states;
    if (logic_dst[9] !== 1'bz || logic_dst[10] !== 1'b1)
      $fatal(1, "in-range wide base and four-state leaf");

    shifted = '{default:0};
    unsigned_base = 128;
    shifted[unsigned_base +: 2] = a[2:3];
    if (shifted[127] !== 0 || shifted[128] !== 3 ||
        shifted[129] !== 4 || shifted[130] !== 0)
      $fatal(1, "unsigned base with its high bit set");
    check_local();

    i = 1;
    source_base = 2;
    b[select_once(i) +: 2] <= a[select_once(source_base) +: 2];
    i = 0;
    source_base = 1;
    a[2] = 13;
    a[3] = 14;
    if (selector_calls != 4)
      $fatal(1, "NBA selectors must be evaluated once at issue");
    check_b("before NBA copy", 32, 3, 5, 41);
    #1;
    check_b("NBA captured selectors and values", 32, 3, 4, 41);

    i = 1;
    b[select_once(i) +: 2] <= '{11, schedule_word(1)};
    i = 3;
    b[i +: 2] <= '{get_value(51), get_value(52)};
    i = 'x;
    b[i +: 2] <= '{get_value(61), get_value(62)};
    if (selector_calls != 5 || rhs_calls != 12)
      $fatal(1, "NBA pattern evaluation");
    check_b("before NBA pattern", 32, 3, 4, 41);
    #1;
    check_b("NBA pattern scheduling order and clipping", 32, 11, 22, 51);

    real_dst = '{1.0, 2.0, 3.0, 4.0};
    real_src = '{7.0, 8.0};
    i = -1;
    real_dst[i +: 2] <= real_src;
    if (real_dst[0] != 1.0)
      $fatal(1, "real leaf updated before NBA");
    #1;
    if (real_dst[0] != 8.0 || real_dst[1] != 2.0 ||
        real_dst[2] != 3.0 || real_dst[3] != 4.0)
      $fatal(1, "real NBA leaf and low overrun");

    words = '{"left", "right"};
    i = 1;
    strings[i +: 2] = words;
    i = 2;
    strings[i +: 2] = '{strings[2], "ignored"};
    if (strings[0] != "" || strings[1] != "left" || strings[2] != "right")
      $fatal(1, "blocking string leaves");

    $display("PASSED");
  end
endmodule
