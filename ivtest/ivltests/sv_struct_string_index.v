// IEEE 1800-2017/2023 6.16 and 7.2: character reads from struct strings.
module sv_struct_string_index;
  typedef struct { string val; int tag; } row_t;
  typedef struct { row_t row; } outer_t;
  row_t row;
  row_t rows[2];
  outer_t outer;
  integer idx, calls;
  function automatic int next_index();
    calls++;
    return 2;
  endfunction
  task automatic check_row(input row_t arg);
    if (arg.val[1] !== "a") $fatal(1, "automatic struct argument");
  endtask
  initial begin
    row.val = "\377\200";
    if (row.val[0] !== -1 || row.val[1] !== -128) $fatal(1, "signed byte");
    row.val = "@abc"; row.tag = 17;
    rows[1].val = "xyz";
    outer.row.val = "nest";
    idx = 3; calls = 0;
    if (row.val[0] !== "@" || row.val[idx] !== "c") $fatal(1, "character value");
    if (row.val[next_index()] !== "b" || calls !== 1) $fatal(1, "index evaluation");
    if (rows[1].val[2] !== "z" || outer.row.val[1] !== "e") $fatal(1, "nested values");
    if ($bits(row.val[0]) !== 8) $fatal(1, "character width");
    check_row(row);
    if (row.tag !== 17 || row.val != "@abc") $fatal(1, "read changed storage");
    $display("PASSED");
  end
endmodule
