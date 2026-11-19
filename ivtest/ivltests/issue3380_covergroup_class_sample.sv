// IEEE 1800-2017/2023 19.4 and 19.8.1
package covergroup_pkg;
  class C;
    bit a, b, f, default_f;
    bit [1:0] enabled, stop;
    bit cross_enabled, bin_enabled;
    local bit secret;

    local function bit local_value();
      return b;
    endfunction

    covergroup cg;
      option.per_instance = 1;
      p: coverpoint (a ^ b);
      hit: coverpoint (a ^ b) { bins one = {1}; }
    endgroup

    covergroup mixed(bit bias) with function sample(bit f = default_f);
      option.per_instance = 1;
      value_cp: coverpoint (f ^ this.secret ^ local_value() ^ bias)
                iff (enabled & ~stop) { bins one = {1}; }
      key_cp: coverpoint a { bins one = {1}; }
      bin_cp: coverpoint a { bins one = {1} iff (bin_enabled && !stop); }
      pair_cp: cross value_cp, key_cp iff (cross_enabled && !stop);
    endgroup

    function new();
      secret = 1;
      cg = new;
      mixed = new(1);
    endfunction

    function void sample_peer(C peer);
      peer.cg.sample();
    endfunction

    function void set_a(bit value);
      a = value;
    endfunction
  endclass

  class D extends C;
    bit a, b;
  endclass
endpackage

module top;
  import covergroup_pkg::*;

  bit a = 0, b = 0, f = 1;
  bit [1:0] enabled = 2'b10, stop = 0;
  bit cross_enabled = 1, bin_enabled = 1;
  int index_calls, actual_calls;

  C left, right, objects[2];
  D inherited;

  function int next_index();
    index_calls++;
    return 1;
  endfunction

  function bit next_actual(C receiver, bit new_b);
    actual_calls++;
    receiver.b = new_b;
    return f;
  endfunction

  initial begin
    left = new;
    right = new;
    objects[0] = left;
    objects[1] = right;
    inherited = new;

    if (left.cg.p.get_inst_coverage() != 0.0)
      $fatal(1, "fresh instance has coverage");
    left.a = 1;
    left.cg.sample();
    if (left.cg.p.get_inst_coverage() != 50.0 ||
        left.cg.hit.get_inst_coverage() != 100.0)
      $fatal(1, "external sample did not read the first instance");
    left.a = 0;
    left.cg.sample();
    if (left.cg.p.get_inst_coverage() != 100.0)
      $fatal(1, "both XOR values should be covered");

    left.a = 1;
    left.sample_peer(right);
    if (right.cg.p.get_inst_coverage() != 50.0 ||
        right.cg.hit.get_inst_coverage() != 0.0)
      $fatal(1, "peer sample read the calling instance");
    right.a = 1;
    objects[next_index()].cg.sample();
    if (index_calls != 1 || right.cg.p.get_inst_coverage() != 100.0 ||
        right.cg.hit.get_inst_coverage() != 100.0)
      $fatal(1, "indexed sample did not evaluate its receiver once");

    inherited.set_a(1);
    inherited.cg.sample();
    if (inherited.cg.hit.get_inst_coverage() != 100.0)
      $fatal(1, "inherited covergroup did not read its declaring class");

    // The module guards are true. These samples must use the object guards.
    left.enabled = 2'b10;
    left.stop = 2'b10;
    left.mixed.sample(.f(next_actual(left, 0)));
    if (actual_calls != 1 ||
        left.mixed.value_cp.get_inst_coverage() != 0.0 ||
        left.mixed.bin_cp.get_inst_coverage() != 0.0 ||
        left.mixed.pair_cp.get_inst_coverage() != 0.0)
      $fatal(1, "false object guard did not suppress a sample");

    // The omitted formal is read from the object. The class field f
    // versus the sample formal f, and the constructor bias, affect the XOR.
    left.stop = 0;
    left.default_f = 1;
    left.mixed.sample();
    if (left.mixed.value_cp.get_inst_coverage() != 100.0 ||
        left.mixed.bin_cp.get_inst_coverage() != 0.0 ||
        left.mixed.pair_cp.get_inst_coverage() != 0.0)
      $fatal(1, "defaulted formal, member, method or guard bound incorrectly");

    // The actual changes b to 1 before the covergroup evaluates local_value().
    // The named formal must be 0 for a hit.
    right.enabled = 2'b10;
    right.cross_enabled = 1;
    right.bin_enabled = 1;
    f = 0;
    right.f = 1;
    right.default_f = 1;
    right.mixed.sample(.f(next_actual(right, 1)));
    if (actual_calls != 2 ||
        right.mixed.value_cp.get_inst_coverage() != 100.0 ||
        right.mixed.bin_cp.get_inst_coverage() != 100.0 ||
        right.mixed.pair_cp.get_inst_coverage() != 100.0)
      $fatal(1, "named formal or true guard did not sample the peer");
    $display("PASSED");
  end
endmodule
