// A specialization named inside a forwarded specialization's body is still
// generic scaffolding (IEEE 1800-2017/2023 8.25): agent#(K) extends
// base_agent#(cfg#(K)), and cfg#(K)'s own get_type() names
// registry#(cfg#(K)). That registry must not run its static initializer, or
// UVM registers the type name twice (OpenTitan kmac: TPRGED for every
// key_sideload_* class). Only the concrete cfg#(byte) registry registers.
package lib_pkg;
int regs[string];
class registry #(type T = int, string Tname = "<unknown>");
  static registry #(T, Tname) me = get();
  static function registry #(T, Tname) get();
    if (me == null) begin me = new; regs[Tname]++; end
    return me;
  endfunction
endclass
class cfg #(type K = int);
  typedef registry #(cfg #(K), "cfg#(K)") type_id;
  static function type_id get_type(); return type_id::get(); endfunction
endclass
class base_agent #(type C = int);
  C c;
endclass
class agent #(type K = int) extends base_agent #(cfg #(K));
endclass
endpackage

module test;
  import lib_pkg::*;
  agent #(byte) a;
  initial begin
    #1;
    if (regs["cfg#(K)"] == 1) $display("PASSED");
    else $display("FAILED: cfg#(K) registered %0d times", regs["cfg#(K)"]);
  end
endmodule
