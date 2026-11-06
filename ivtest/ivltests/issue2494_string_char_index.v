module issue2494_string_char_index;
  string s, a[1];
  logic [127:0] ix_x, ix_z, ix_wide, ix_mixed;

  function automatic logic [127:0] identity(input logic [127:0] value);
    return value;
  endfunction

  task automatic check(input string label, input string actual,
                       input string expected);
    if (actual != expected)
      $fatal(1, "%s: expected %s, got %s", label, expected, actual);
  endtask

  initial begin
    ix_x = 'x;
    ix_z = 'z;
    ix_wide = '0;
    ix_wide[100] = 1'b1;
    ix_mixed = '0;
    ix_mixed[1:0] = 2'b1x;

    s = "ABC"; s[ix_x] = "X"; check("variable X", s, "XBC");
    s = "ABC"; s[ix_z] = "Z"; check("variable Z", s, "ZBC");
    s = "ABC"; s[ix_wide] = "Y"; check("variable wide", s, "YBC");
    s = "ABC"; s[ix_mixed] = "Z"; check("variable mixed", s, "ABZ");

    s = "ABC"; s[identity(ix_x)] = "X";
    check("function X", s, "XBC");
    s = "ABC"; s[identity(ix_z)] = "Z";
    check("function Z", s, "ZBC");
    s = "ABC"; s[identity(ix_wide)] = "Y";
    check("function wide", s, "YBC");
    s = "ABC"; s[identity(ix_mixed)] = "Z";
    check("function mixed", s, "ABZ");

    a[0] = "ABC"; a[0][ix_x] = "X"; check("array X", a[0], "XBC");
    a[0] = "ABC"; a[0][ix_z] = "Z"; check("array Z", a[0], "ZBC");
    a[0] = "ABC"; a[0][ix_wide] = "Y"; check("array wide", a[0], "YBC");
    a[0] = "ABC"; a[0][ix_mixed] = "Z"; check("array mixed", a[0], "ABZ");

    a[0] = "ABC"; a[0][identity(ix_x)] = "X";
    check("array function X", a[0], "XBC");
    a[0] = "ABC"; a[0][identity(ix_z)] = "Z";
    check("array function Z", a[0], "ZBC");
    a[0] = "ABC"; a[0][identity(ix_wide)] = "Y";
    check("array function wide", a[0], "YBC");
    a[0] = "ABC"; a[0][identity(ix_mixed)] = "Z";
    check("array function mixed", a[0], "ABZ");

    $display("PASSED");
  end
endmodule
