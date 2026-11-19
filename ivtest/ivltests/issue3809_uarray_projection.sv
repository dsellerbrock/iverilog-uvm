module issue3809_uarray_projection;
  int m[0:2][0:3], s[0:1];
  int expected[0:2][0:3];
  integer i, j;
  logic [129:0] wide;
  int calls[0:2], value_calls;

  int cube[3:4][6:3][-1:1];
  int nested[1:0][4:2][0:1][3:2];
  int rows[0:1][2:3];
  int p, b, k;
  int q[$];
  real weights[0:2][0:1][1:0];

  typedef int pair_t[1:0];
  typedef real weight_pairs_t[1:0][0:1];
  function automatic pair_t value();
    value_calls++;
    value[1] = 71;
    value[0] = 82;
  endfunction

  function automatic integer select_once(int which, integer index);
    calls[which]++;
    return index;
  endfunction

  task automatic check_matrix(string label_text);
    for (int row = 0; row < 3; row++)
      for (int col = 0; col < 4; col++)
        if (m[row][col] !== expected[row][col])
          $fatal(1, "%s m[%0d][%0d] got %0d expected %0d",
                 label_text, row, col, m[row][col], expected[row][col]);
  endtask

  task automatic check_cube(bit after_nba);
    for (int page = 3; page <= 4; page++)
      for (int row = 3; row <= 6; row++)
        for (int col = -1; col <= 1; col++) begin
          int want;
          want = 0;
          if (after_nba && page == 4 && col == 0) begin
            if (row == 5) want = 11;
            if (row == 4) want = 22;
          end
          if (cube[page][row][col] !== want)
            $fatal(1, "prefixed NBA cube[%0d][%0d][%0d]", page, row, col);
        end
  endtask

  initial begin
    for (int row = 0; row < 3; row++)
      for (int col = 0; col < 4; col++) begin
        expected[row][col] = 100 + 10 * row + col;
        m[row][col] = expected[row][col];
      end
    s[0] = 11;
    s[1] = 22;

    i = 1;
    j = 2;
    m[select_once(0, i)+:2][select_once(1, j)] = s;
    if (calls[0] != 1 || calls[1] != 1) $fatal(1, "selector evaluated again");
    expected[1][2] = 11;
    expected[2][2] = 22;
    check_matrix("strided");

    i = -1;
    m[i+:2][j] = s;
    expected[0][2] = 22;
    check_matrix("valid tail of low-side overrun");

    i = 2;
    m[i+:2][j] = s;
    expected[2][2] = 11;
    check_matrix("high-side overrun");

    i = 0;
    j = 4;
    m[i+:2][j] = s;
    j = -1;
    m[i+:2][j] = s;
    j = 'z;
    m[i+:2][j] = s;
    j = 2;
    i = 'x;
    m[i+:2][j] = value();
    if (value_calls != 1) $fatal(1, "invalid destination skipped RHS");
    wide = 130'd1 << 128;
    m[wide+:2][j] = s;
    m[0+:2][wide] = s;
    check_matrix("invalid indices");

    i = 1;
    m[i+:2][2] = m[0+:2][2];
    expected[1][2] = 22;
    expected[2][2] = 11;
    check_matrix("overlapping RHS slice");

    i = -1;
    m[i+:2][1] = value();
    expected[0][1] = 82;
    if (value_calls != 2) $fatal(1, "function value evaluated again");
    check_matrix("function snapshot");

    i = 1;
    m[i+:2][0] = '{33, 44};
    expected[1][0] = 33;
    expected[2][0] = 44;
    q = {55, 66};
    m[i+:2][1] = q;
    expected[1][1] = 55;
    expected[2][1] = 66;
    check_matrix("pattern and queue");

    p = 4;
    b = 5;
    k = 0;
    cube[select_once(0, p)][select_once(1, b)-:2][select_once(2, k)] <= s;
    check_cube(0);
    if (calls[0] != 2 || calls[1] != 2 || calls[2] != 1)
      $fatal(1, "NBA selectors evaluated again");
    p = 3;
    b = 6;
    k = -1;
    s[0] = 99;
    s[1] = 88;
    #1;
    check_cube(1);
    p = 5;
    cube[p][b-:2][k] = s;
    check_cube(1);

    rows[0][2] = 201;
    rows[0][3] = 202;
    rows[1][2] = 211;
    rows[1][3] = 212;
    p = 1;
    b = 3;
    k = 1;
    nested[p][b-:2][k] = rows;
    b = 2;
    nested[p][b-:2][0] <= rows;
    p = 0;
    b = 4;
    rows[0][2] = 999;
    #1;
    for (int page = 0; page <= 1; page++)
      for (int row = 2; row <= 4; row++)
        for (int col = 0; col <= 1; col++)
          for (int word = 2; word <= 3; word++) begin
            int want;
            want = 0;
            if (page == 1) begin
              if ((row == 3 && col == 1) || (row == 2 && col == 0))
                want = word == 3 ? 201 : 202;
              if (row == 2 && col == 1)
                want = word == 3 ? 211 : 212;
            end
            if (nested[page][row][col][word] !== want)
              $fatal(1, "subarray shape nested[%0d][%0d][%0d][%0d]",
                     page, row, col, word);
          end

    i = -1;
    weights[i+:2][1] <= weight_pairs_t'{ '{1.0, 2.0}, '{3.0, 4.0} };
    #1;
    if (weights[0][1][1] != 3.0 || weights[0][1][0] != 4.0 ||
        weights[0][0][1] != 0.0 || weights[1][1][1] != 0.0)
      $fatal(1, "typed pattern with opposite dimension directions");

    $display("PASSED");
  end
endmodule
