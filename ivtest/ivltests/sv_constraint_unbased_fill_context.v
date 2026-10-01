// IEEE 1800-2017/2023 5.7.1, 11.4.13, 11.8.2, 18.3:
// unbased '1 fills the comparison or inside width; sized 1'b1 stays one.
class fill_item;
  rand bit [15:0] value;
endclass

module main;
  bit [1:0] bits2;
  logic [1:0] logic2;
  bit signed [15:0] signed16;
  bit [255:0] bits256;
  logic [255:0] logic256;
  fill_item item;
  initial begin
    if (!std::randomize(bits2) with { bits2 == '1; }
        || bits2 !== 2'b11) $fatal(1, "direct fill");
    if (!std::randomize(logic2) with { '1 == logic2; }
        || logic2 !== 2'b11) $fatal(1, "reversed fill");
    if (!std::randomize(signed16) with { signed16 == '1; }
        || signed16 !== 16'hffff) $fatal(1, "signed fill");
    if (!std::randomize(bits2) with { bits2 == 1'b1; }
        || bits2 !== 2'b01) $fatal(1, "sized one");
    if (!std::randomize(logic2) with { logic2 == '0; }
        || logic2 !== 2'b00) $fatal(1, "zero fill");
    if (!std::randomize(bits2) with {
      bits2 == 2'b11; bits2 inside {32'd0, '1};
    } || bits2 !== 2'b11) $fatal(1, "per-member inside fill");
    if (std::randomize(bits2) with { bits2 != '1; bits2 == 2'b11; }
        || bits2 !== 2'b11) $fatal(1, "inequality rollback");
    if (!std::randomize(bits256) with {
      bits256 inside {0, '1}; bits256 != 0;
    } || bits256 !== '1) $fatal(1, "wide bit inside");
    if (!std::randomize(logic256) with {
      logic256 inside {0, '1}; logic256 != 0;
    } || logic256 !== '1) $fatal(1, "wide logic inside");
    if (!std::randomize(logic256) with {
      logic256 inside {0, 1'b1}; logic256 != 0;
    } || logic256 !== 256'd1) $fatal(1, "wide sized inside");
    bits256 = 256'hcafe;
    if (std::randomize(bits256) with { bits256 == '1; bits256 == 0; }
        || bits256 !== 256'hcafe) $fatal(1, "unsat rollback");
    item = new;
    if (!item.randomize() with { value == '1; }
        || item.value !== 16'hffff) $fatal(1, "class fill");
    $display("PASSED");
  end
endmodule
