// Nonstandard compatibility under -gcommercial-unsafe: a leading `static'
// on a module-scope task/function (IEEE 1800-2017/2023 A.2.6 requires
// `task static'), and an import directly in a class body (A.1.8/A.2.1.3
// forbid it). Commercial simulators accept both, and OpenTitan's spid and
// uart DV use them. Strict mode still rejects both: see
// sv_static_qualifier_module_task_fail and sv_class_body_import_fail.
package cfg_pkg;
  typedef enum logic [1:0] { A, B, C } mode_e;
  parameter int WIDTH = 7;
  function automatic int twice(int x); return 2 * x; endfunction
endpackage
class item;
  import cfg_pkg::*;
  mode_e mode = C;
  bit [WIDTH-1:0] data;
  function int calc(); return twice(WIDTH); endfunction
endclass
class item2;
  import cfg_pkg::mode_e;
  mode_e m = cfg_pkg::B;
endclass
module t;
  int calls = 0;
  static task bump(input int n); calls += n; endtask
  static function int sq(int x); return x * x; endfunction
  item it = new; item2 it2 = new;
  initial begin
    bump(2); bump(3);
    $display("calls=%0d sq=%0d mode=%0d width=%0d calc=%0d m=%0d", calls, sq(4), it.mode, $bits(it.data), it.calc(), it2.m);
    if (calls == 5 && sq(4) == 16 && it.mode == 2 && $bits(it.data) == 7 && it.calc() == 14 && it2.m == 1) $display("PASSED"); else $display("FAILED");
  end
endmodule
