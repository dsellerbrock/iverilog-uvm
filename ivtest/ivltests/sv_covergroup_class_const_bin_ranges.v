// IEEE 1800-2017/2023 8.19 and 19.5: enclosing-class constants may
// define per-object embedded-covergroup bin ranges.
module top;
  class model;
    const int unsigned unsigned_high;
    const int signed signed_low;
    const int signed signed_high;
    const bit [7:0] shift_base;
    const int signed shift_count;
    const logic [3:0] maybe_high;
    const int signed declaration_global_low = -4;
    const int signed declaration_global_high = -2;
    static const int signed GLOBAL_CENTER = -1;
    const static int signed GLOBAL_RADIUS = 2;

    covergroup unsigned_cg with function sample(int unsigned value);
      option.per_instance = 1;
      cp: coverpoint value { bins values[] = {[0:unsigned_high]}; }
    endgroup
    covergroup signed_cg with function sample(int signed value);
      option.per_instance = 1;
      cp: coverpoint value { bins window = {[signed_low:signed_high]}; }
    endgroup
    covergroup arithmetic_cg(int signed bias)
        with function sample(int signed value);
      option.per_instance = 1;
      cp: coverpoint value {
        bins window = {[(signed_low-bias):((signed_high*2)+bias)]};
      }
    endgroup
    covergroup shift_cg with function sample(bit [7:0] value);
      option.per_instance = 1;
      cp: coverpoint value { bins window = {[0:(shift_base << shift_count)]}; }
    endgroup
    covergroup xz_cg with function sample(bit [3:0] value);
      option.per_instance = 1;
      cp: coverpoint value { bins xz_values[] = {[0:maybe_high]}; }
    endgroup
    covergroup global_cg with function sample(int signed value);
      option.per_instance = 1;
      cp: coverpoint value {
        bins values[] = {[(GLOBAL_CENTER-GLOBAL_RADIUS):
                          (GLOBAL_CENTER+GLOBAL_RADIUS)]};
      }
    endgroup
    covergroup declaration_global_cg with function sample(int signed value);
      option.per_instance = 1;
      cp: coverpoint value {
        bins values = {[declaration_global_low:declaration_global_high]};
      }
    endgroup

    function new(int unsigned unsigned_high_arg,
                 int signed signed_low_arg,
                 int signed signed_high_arg,
                 bit [7:0] shift_base_arg,
                 int signed shift_count_arg,
                 logic [3:0] maybe_high_arg,
                 int signed bias_arg);
      unsigned_high = unsigned_high_arg;
      signed_low = signed_low_arg;
      signed_high = signed_high_arg;
      shift_base = shift_base_arg;
      shift_count = shift_count_arg;
      maybe_high = maybe_high_arg;
      unsigned_cg = new;
      signed_cg = new;
      arithmetic_cg = new(bias_arg);
      shift_cg = new;
      xz_cg = new;
      global_cg = new;
      declaration_global_cg = new;
    endfunction
  endclass

  model narrow;
  model wide;
  model narrow_again;

  initial begin
    narrow = new(1, -2, 1, 8'h80, 1, 4'bx001, 1);
    wide = new(3, 2, 5, 8'h03, 1, 4'h3, 1);
    narrow_again = new(1, -2, 1, 8'h80, 1, 4'h0, 1);

    narrow.unsigned_cg.sample(3);
    wide.unsigned_cg.sample(3);
    narrow_again.unsigned_cg.sample(3);
    if (narrow.unsigned_cg.get_inst_coverage() != 0.0 ||
        wide.unsigned_cg.get_inst_coverage() != 25.0 ||
        narrow_again.unsigned_cg.get_inst_coverage() != 0.0)
      $fatal(1, "unsigned parent ranges shared a cache");
    narrow.unsigned_cg.sample(1);
    narrow_again.unsigned_cg.sample(1);
    if (narrow.unsigned_cg.get_inst_coverage() != 50.0 ||
        wide.unsigned_cg.get_inst_coverage() != 25.0 ||
        narrow_again.unsigned_cg.get_inst_coverage() != 50.0)
      $fatal(1, "unsigned coverage state was shared");

    narrow.signed_cg.sample(-2);
    wide.signed_cg.sample(-2);
    narrow_again.signed_cg.sample(-2);
    if (narrow.signed_cg.get_inst_coverage() != 100.0 ||
        wide.signed_cg.get_inst_coverage() != 0.0 ||
        narrow_again.signed_cg.get_inst_coverage() != 100.0)
      $fatal(1, "signed endpoints lost their type");
    wide.signed_cg.sample(5);
    if (wide.signed_cg.get_inst_coverage() != 100.0)
      $fatal(1, "wide signed range was not retained");

    narrow.arithmetic_cg.sample(0);
    wide.arithmetic_cg.sample(0);
    narrow_again.arithmetic_cg.sample(0);
    if (narrow.arithmetic_cg.get_inst_coverage() != 100.0 ||
        wide.arithmetic_cg.get_inst_coverage() != 0.0 ||
        narrow_again.arithmetic_cg.get_inst_coverage() != 100.0)
      $fatal(1, "mixed p/pp arithmetic shared a cache");
    wide.arithmetic_cg.sample(11);
    if (wide.arithmetic_cg.get_inst_coverage() != 100.0)
      $fatal(1, "mixed p/pp arithmetic was incorrect");

    narrow.shift_cg.sample(6);
    wide.shift_cg.sample(6);
    narrow_again.shift_cg.sample(6);
    if (narrow.shift_cg.get_inst_coverage() != 0.0 ||
        wide.shift_cg.get_inst_coverage() != 100.0 ||
        narrow_again.shift_cg.get_inst_coverage() != 0.0)
      $fatal(1, "parent shift width was lost");
    narrow.shift_cg.sample(0);
    narrow_again.shift_cg.sample(0);
    if (narrow.shift_cg.get_inst_coverage() != 100.0 ||
        narrow_again.shift_cg.get_inst_coverage() != 100.0)
      $fatal(1, "wrapped parent shift was not retained");

    narrow.xz_cg.sample(0);
    wide.xz_cg.sample(3);
    narrow_again.xz_cg.sample(0);
    if (narrow.xz_cg.get_inst_coverage() != 0.0 ||
        wide.xz_cg.get_inst_coverage() != 25.0 ||
        narrow_again.xz_cg.get_inst_coverage() != 100.0)
      $fatal(1, "parent X endpoint was coerced or resolved before linking");

    narrow.global_cg.sample(-3);
    if (narrow.global_cg.get_inst_coverage() != 20.0)
      $fatal(1, "global class-constant arithmetic was not resolved");
    narrow.declaration_global_cg.sample(-3);
    if (narrow.declaration_global_cg.get_inst_coverage() != 100.0)
      $fatal(1, "declaration-initialized class constants were not resolved");
    $display("PASSED");
  end
endmodule
