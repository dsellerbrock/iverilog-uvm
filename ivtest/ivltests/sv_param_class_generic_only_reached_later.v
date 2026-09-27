// A specialization first requested only from generic bodies, and later from
// concrete code, is a runtime type after all (IEEE 1800-2017/2023 8.25).
// item#(byte) is first named in holder's generic master, so the registry its
// get_type() names starts out generic-body-only too. When user#(int)'s method
// later names item#(byte), both marks must clear, or the registry's static
// initializer never runs and UVM never registers the type.
package lib_pkg;
int regs[string];
class registry #(type T = int, string Tname = "<unknown>");
  static registry #(T, Tname) me = get();
  static function registry #(T, Tname) get();
    if (me == null) begin me = new; regs[Tname]++; end
    return me;
  endfunction
endclass
class item #(type K = int);
  typedef registry #(item #(K), "item#(K)") type_id;
  static function type_id get_type(); return type_id::get(); endfunction
endclass
class holder #(type T = int);
  item #(byte) x;
  function void f(); void'(x.get_type()); endfunction
endclass
class user #(type T = int);
  function void g();
    item #(byte) z;
    void'(z.get_type());
  endfunction
endclass
endpackage

module test;
  import lib_pkg::*;
  user #(int) u;
  initial begin
    #1;
    if (regs["item#(K)"] == 1) $display("PASSED");
    else $display("FAILED: item#(K) registered %0d times", regs["item#(K)"]);
  end
endmodule
