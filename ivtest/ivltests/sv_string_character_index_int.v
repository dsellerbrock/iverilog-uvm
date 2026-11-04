module sv_string_character_index_int;
  string value, values[1];
  logic [127:0] wide, unknown, mixed;

  function automatic logic [127:0] identity(input logic [127:0] arg);
    return arg;
  endfunction

  initial begin
    wide = 0; wide[100] = 1;
    unknown = 'x;
    mixed = 0; mixed[1:0] = 2'b1x;

    value = "ABC"; value[unknown] = "X";
    if (value != "XBC") $fatal(1, "variable X index: %s", value);
    value = "ABC"; value[wide] = "Y";
    if (value != "YBC") $fatal(1, "variable wide index: %s", value);
    value = "ABC"; value[mixed] = "Z";
    if (value != "ABZ") $fatal(1, "variable mixed index: %s", value);

    value = "ABC"; value[identity(unknown)] = "X";
    if (value != "XBC") $fatal(1, "call X index: %s", value);
    value = "ABC"; value[identity(wide)] = "Y";
    if (value != "YBC") $fatal(1, "call wide index: %s", value);
    value = "ABC"; value[identity(mixed)] = "Z";
    if (value != "ABZ") $fatal(1, "call mixed index: %s", value);

    values[0] = "ABC"; values[0][unknown] = "X";
    if (values[0] != "XBC") $fatal(1, "array X index: %s", values[0]);
    values[0] = "ABC"; values[0][wide] = "Y";
    if (values[0] != "YBC") $fatal(1, "array wide index: %s", values[0]);
    values[0] = "ABC"; values[0][mixed] = "Z";
    if (values[0] != "ABZ") $fatal(1, "array mixed index: %s", values[0]);

    values[0] = "ABC"; values[0][identity(unknown)] = "X";
    if (values[0] != "XBC") $fatal(1, "array call X index: %s", values[0]);
    values[0] = "ABC"; values[0][identity(wide)] = "Y";
    if (values[0] != "YBC") $fatal(1, "array call wide index: %s", values[0]);
    values[0] = "ABC"; values[0][identity(mixed)] = "Z";
    if (values[0] != "ABZ") $fatal(1, "array call mixed index: %s", values[0]);

    $display("PASS");
  end
endmodule
