// IEEE 1800-2017 7.4.6 / 1800-2023 7.4.5 and 19.5:
// a covergroup sample formal retains its unpacked array direction when a
// variable word index is followed by a packed member or bit select.
package sample_flags_pkg;
  typedef struct packed { logic Z, L, M, C; } flags_t;
  class sample_item;
    flags_t flags[1:0];
  endclass
endpackage

module top;
  import sample_flags_pkg::*;

  covergroup selected_cg with function sample(bit fg, bit [1:0] idx,
                                               flags_t flags[1:0]);
    option.per_instance = 1;
    member_cp: coverpoint {fg, flags[fg].C} {
      bins first = {2'b00};
      bins second = {2'b11};
    }
    bit0_cp: coverpoint {fg, flags[fg][0]} {
      bins first = {2'b00};
      bins second = {2'b11};
    }
    dynamic_bit_cp: coverpoint {fg, idx[1], flags[fg][idx]} {
      bins first_bit0 = {3'b000};
      bins first_bit3 = {3'b011};
      bins second_bit0 = {3'b101};
      bins second_bit3 = {3'b110};
    }
  endgroup

  selected_cg cov;
  selected_cg bare_cov;
  selected_cg opposite_cov;
  flags_t module_flags[1:0];
  flags_t opposite_flags[0:1];
  sample_item item;
  initial begin
    item = new;
    item.flags[0] = 4'b1010;
    item.flags[1] = 4'b0101;
    cov = new;

    cov.sample(0, 0, item.flags);
    if (cov.member_cp.get_inst_coverage() != 50.0 ||
        cov.bit0_cp.get_inst_coverage() != 50.0 ||
        cov.dynamic_bit_cp.get_inst_coverage() != 25.0)
      $fatal(1, "first selected array word did not hit its bins");

    item.flags[0] = 4'b1111;
    item.flags[1] = 4'b0100;
    cov.sample(1, 0, item.flags);
    if (cov.member_cp.get_inst_coverage() != 50.0 ||
        cov.bit0_cp.get_inst_coverage() != 50.0 ||
        cov.dynamic_bit_cp.get_inst_coverage() != 25.0)
      $fatal(1, "new array contents changed earlier sample bins");

    item.flags[0] = 4'b1010;
    item.flags[1] = 4'b0101;
    cov.sample(1, 0, item.flags);
    if (cov.member_cp.get_inst_coverage() != 100.0 ||
        cov.bit0_cp.get_inst_coverage() != 100.0 ||
        cov.dynamic_bit_cp.get_inst_coverage() != 50.0)
      $fatal(1, "second selected array word did not hit its bins");

    cov.sample(0, 3, item.flags);
    cov.sample(1, 3, item.flags);
    if (cov.dynamic_bit_cp.get_inst_coverage() != 100.0 ||
        cov.get_inst_coverage() != 100.0)
      $fatal(1, "dynamic packed bit selection did not cover both words");

    module_flags[0] = 4'b1010;
    module_flags[1] = 4'b0101;
    bare_cov = new;
    bare_cov.sample(0, 0, module_flags);
    if (bare_cov.member_cp.get_inst_coverage() != 50.0 ||
        bare_cov.dynamic_bit_cp.get_inst_coverage() != 25.0)
      $fatal(1, "bare array first word was not sampled");
    bare_cov.sample(1, 0, module_flags);
    bare_cov.sample(0, 3, module_flags);
    bare_cov.sample(1, 3, module_flags);
    if (bare_cov.get_inst_coverage() != 100.0)
      $fatal(1, "bare array did not cover distinct word values");

    // The formal's left index 1 receives the actual's left index 0.
    opposite_flags[0] = 4'b0101;
    opposite_flags[1] = 4'b1010;
    opposite_cov = new;
    opposite_cov.sample(0, 0, opposite_flags);
    if (opposite_cov.member_cp.get_inst_coverage() != 50.0 ||
        opposite_cov.dynamic_bit_cp.get_inst_coverage() != 25.0)
      $fatal(1, "opposite-range first word was not copied by position");
    opposite_cov.sample(1, 0, opposite_flags);
    opposite_cov.sample(0, 3, opposite_flags);
    opposite_cov.sample(1, 3, opposite_flags);
    if (opposite_cov.get_inst_coverage() != 100.0)
      $fatal(1, "opposite-range actual did not preserve word order");
    $display("PASSED");
  end
endmodule
