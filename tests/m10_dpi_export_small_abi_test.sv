// Commercial-simulator DPI export ABI: C-facing stubs must preserve the
// declared shortreal/float, chandle/void*, scalar svBit/svLogic, and string
// types. Output formals also pin that the generated wrapper never reads the
// caller's uninitialized output object. The automatic string export pins that
// copy-out storage survives invocation-context teardown.
module m10_dpi_export_small_abi_test;
  import "DPI-C" context function int c_check_small_exports();

  function shortreal sv_shortreal(
      input shortreal value, output shortreal out_value,
      inout shortreal inout_value);
    out_value = -2.5;
    inout_value += 0.5;
    return value + 4.0;
  endfunction

  function chandle sv_chandle(
      input chandle value, output chandle out_value,
      inout chandle inout_value);
    out_value = value;
    inout_value = value;
    return value;
  endfunction

  function bit sv_bit(input bit value, output bit out_value,
                      inout bit inout_value);
    out_value = 1'b1;
    inout_value = ~inout_value;
    return value;
  endfunction

  function logic sv_logic(input logic value, output logic out_value,
                          inout logic inout_value);
    out_value = 1'bz;
    inout_value = 1'bx;
    return value;
  endfunction

  function automatic string sv_string(
      input string value, output string out_value,
      inout string inout_value);
    out_value = {"out:", value};
    inout_value = {inout_value, ":io"};
    return {"ret:", value};
  endfunction

  function int sv_bit_vector(
      input bit [95:0] value, output bit [95:0] out_value,
      inout bit [95:0] inout_value);
    out_value = 96'h01234567_89abcdef_fedcba98;
    inout_value = inout_value ^ value;
    return 17;
  endfunction

  function int sv_logic_vector(
      input logic [65:0] value, output logic [65:0] out_value,
      inout logic [65:0] inout_value);
    out_value = value;
    inout_value = value;
    return 23;
  endfunction

  export "DPI-C" function sv_shortreal;
  export "DPI-C" function sv_chandle;
  export "DPI-C" function sv_bit;
  export "DPI-C" function sv_logic;
  export "DPI-C" function sv_string;
  export "DPI-C" function sv_bit_vector;
  export "DPI-C" function sv_logic_vector;

  initial begin
    if (c_check_small_exports() == 0)
      $display("PASS m10_dpi_export_small_abi_test");
    else
      $display("FAIL m10_dpi_export_small_abi_test");
    $finish;
  end
endmodule
