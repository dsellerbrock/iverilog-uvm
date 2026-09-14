module sv_packed_wide_constant_select_read;
  logic [7:0] value = 8'ha5;
  logic [1:0][2:0][7:0] cube;
  logic [3:0] selected;
  logic [15:0] subarrays;
  string rendered;
  longint signed_dynamic_base = 64'h1_0000_0000;
  logic signed [127:0] signed_dynamic_wide;

  task automatic check_value(input logic condition, input string label);
    if (condition !== 1'b1)
      $fatal(1, "FAILED: %s", label);
  endtask

  initial begin
    #1;
    rendered = $sformatf("%b", value[64'h1_0000_0000 +: 4]);
    check_value(rendered == "xxxx", "formatted +: 64-bit base");
    rendered = $sformatf("%b", value[64'hffff_ffff_ffff_ffff -: 4]);
    check_value(rendered == "xxxx", "formatted -: maximum unsigned base");
    rendered = $sformatf("%b", value[(128'd1 << 100) +: 4]);
    check_value(rendered == "xxxx", "formatted +: 128-bit base");
    rendered = $sformatf("%b", value[signed_dynamic_base +: 4]);
    check_value(rendered == "xxxx", "signed dynamic 64-bit VPI base");
    signed_dynamic_wide = 128'sd1 << 100;
    rendered = $sformatf("%b", value[signed_dynamic_wide +: 4]);
    check_value(rendered == "xxxx", "signed dynamic 128-bit VPI base");
    $display("wide=%b", value[64'h1_0000_0000 +: 4]);

    selected = value[64'h1_0000_0000 +: 4];
    check_value(selected === 4'bxxxx, "assigned +: wide base");
    selected = value[64'hffff_ffff_ffff_ffff -: 4];
    check_value(selected === 4'bxxxx, "assigned -: wide base");
    check_value($isunknown(value[32'hffff_ffff +: 4]),
                "system function unsigned 32-bit base");

    check_value(value[2 +: 4] === 4'b1001, "ordinary +: constant");
    check_value(value[5 -: 4] === 4'b1001, "ordinary -: constant");
    check_value(value[-2 +: 4] === 4'b01xx,
                "signed negative +: partial overlap");
    check_value(value[1 -: 4] === 4'b01xx,
                "signed negative -: partial overlap");
    check_value(value[2'bx +: 4] === 4'bxxxx, "X constant base");
    check_value(value[2'bz -: 4] === 4'bxxxx, "Z constant base");

    cube = 48'h123456789abc;
    subarrays = cube[1][0 +: 2];
    check_value(subarrays === 16'h3456, "subarray select unchanged");
    $display("PASSED");
  end
endmodule
