module main;
  int m [0:1][0:3];
  logic [7:0] n [1:0][-2:1];
  integer i, j, calls, errors;
  logic [3:0] unknown_index;
  int value;
  logic [7:0] four_value;

  function integer index_once(input integer v);
    calls = calls + 1;
    return v;
  endfunction

  initial begin
    errors = 0; calls = 0;
    m[0][3] = 4; m[1][0] = 5;
    i = 4; m[0][index_once(i)] = 99; value = m[0][index_once(i)];
    if (m[1][0] !== 5 || value !== 0 || calls != 2) errors++;
    i = -1; m[1][i] = 98; value = m[1][i];
    if (m[0][3] !== 4 || value !== 0) errors++;
    unknown_index = 'x; m[1][unknown_index] = 97;
    value = m[1][unknown_index];
    if (m[1][0] !== 5 || value !== 0) errors++;
    i = 1; j = 3; m[i][j] = 42;
    if (m[1][3] !== 42 || m[i][j] !== 42) errors++;
    n[0][1] = 8'h35; n[1][-2] = 8'h64;
    i = 2; n[0][i] = 8'hff; four_value = n[0][i];
    if (n[1][-2] !== 8'h64 || four_value !== 8'hxx) errors++;
    i = -3; n[1][i] <= 8'hff;
    #1;
    four_value = n[1][i];
    if (n[0][1] !== 8'h35 || four_value !== 8'hxx) errors++;
    if (errors) $display("FAIL: %0d", errors);
    else $display("PASS");
  end
endmodule
