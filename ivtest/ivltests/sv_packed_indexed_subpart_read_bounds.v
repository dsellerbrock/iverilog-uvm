module sv_packed_indexed_subpart_read_bounds;
  logic [1:0][7:0] words;
  logic [1:0][12:5] nonzero;
  logic [1:0][5:12] ascending;
  logic [5:12] ascending_reference;
  logic [1:0][2:0][7:0] cube;
  logic [7:0] cube_reference;
  logic [15:0] subarrays;
  logic [3:0] value;
  integer calls;
  integer continuous_index;
  logic [63:0] wide_index;
  logic signed [127:0] signed_wide_index;
  logic [127:0] unsigned_wide_index;
  wire [3:0] continuous_value = words[0][continuous_index +: 4];

  function automatic integer counted_index;
    calls += 1;
    return 6;
  endfunction

  task automatic check_value(input logic condition, input string label);
    if (condition !== 1'b1) begin
      $fatal(1, "FAILED: %s", label);
    end
  endtask

  initial begin
    words[0] = 8'ha5;
    words[1] = 8'h3c;

    value = words[0][8 +: 4];
    check_value(value === 4'bxxxx, "wholly above fixed element");
    value = words[1][-1 -: 4];
    check_value(value === 4'bxxxx, "wholly below fixed element");
    value = words[0][6 +: 4];
    check_value(value === 4'bxx10, "partial upper overlap");
    value = words[0][1 -: 4];
    check_value(value === 4'b01xx, "partial lower overlap");

    nonzero[0] = 8'ha5;
    value = nonzero[0][11 +: 4];
    check_value(value === 4'bxx10, "nonzero descending upper bound");
    value = nonzero[0][6 -: 4];
    check_value(value === 4'b01xx, "nonzero descending lower bound");

    ascending[0] = 8'ha5;
    ascending_reference = 8'ha5;
    value = ascending[0][11 +: 4];
    check_value(value === ascending_reference[11 +: 4],
           "ascending inner range plus select");
    value = ascending[0][6 -: 4];
    check_value(value === ascending_reference[6 -: 4],
           "ascending inner range minus select");

    cube = 48'h123456789abc;
    cube_reference = cube[1][2];
    value = cube[1][2][6 +: 4];
    check_value(value === cube_reference[6 +: 4],
           "multiple valid fixed prefixes");
    subarrays = cube[1][0 +: 2];
    check_value(subarrays === 16'h3456, "subarray select unchanged");

    continuous_index = 6;
    #1;
    check_value(continuous_value === 4'bxx10,
           "continuous nested select synthesis");
    calls = 0;
    value = words[0][counted_index() +: 4];
    check_value(calls == 1, "dynamic index evaluated once");
    check_value(value === 4'bxx10, "counted partial overlap value");

    value = words[0][2'bx +: 4];
    check_value(value === 4'bxxxx, "X index");
    value = words[0][2'bz -: 4];
    check_value(value === 4'bxxxx, "Z index");
    value = words[0][64'h1_0000_0000 +: 4];
    check_value(value === 4'bxxxx, "wide unsigned constant index");
    value = words[0][64'hffff_ffff_ffff_ffff -: 4];
    check_value(value === 4'bxxxx, "maximum unsigned constant index");
    wide_index = 64'h1_0000_0000;
    value = words[0][wide_index +: 4];
    check_value(value === 4'bxxxx, "wide unsigned dynamic index");
    wide_index = 64'hffff_ffff_ffff_ffff;
    value = words[0][wide_index -: 4];
    check_value(value === 4'bxxxx, "maximum unsigned dynamic index");
    signed_wide_index = -128'sd2;
    value = words[0][signed_wide_index +: 4];
    check_value(value === 4'b01xx, "wide signed negative partial overlap");
    signed_wide_index = -(128'sd1 << 100);
    value = words[0][signed_wide_index +: 4];
    check_value(value === 4'bxxxx, "wide signed negative saturation");
    unsigned_wide_index = 128'd1 << 100;
    value = words[0][unsigned_wide_index +: 4];
    check_value(value === 4'bxxxx, "wide unsigned positive saturation");
    value = words[0][32'hffff_ffff +: 4];
    check_value(value === 4'bxxxx, "unsigned 32-bit immediate index");
    $display("PASSED");
  end
endmodule
