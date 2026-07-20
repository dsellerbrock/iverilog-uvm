// M13B: bind-to-instance forms (IEEE 1800-2017 23.11).
//  - bind <hier.path> ...        : bound instance appears ONLY in that
//                                  one target instance;
//  - bind <mod> : <inst list> ...: bound instance appears in every
//                                  instance of <mod> whose instance
//                                  name is listed;
//  - bind <mod> ...              : (pre-existing) every instance.
// The counters verify the exact activation counts: 1 for the path
// form, 2 for the list form (u_b in both mids), 4 for the definition
// form (all four leaves).

package m13b_bind_cnt_pkg;
  int unsigned c_path = 0;
  int unsigned c_list = 0;
  int unsigned c_def  = 0;
endpackage

module m13b_checker_path(input logic [7:0] d);
  initial #1 m13b_bind_cnt_pkg::c_path = m13b_bind_cnt_pkg::c_path + 1;
endmodule

module m13b_checker_list(input logic [7:0] d);
  initial #1 m13b_bind_cnt_pkg::c_list = m13b_bind_cnt_pkg::c_list + 1;
endmodule

module m13b_checker_def(input logic [7:0] d);
  initial #1 m13b_bind_cnt_pkg::c_def = m13b_bind_cnt_pkg::c_def + 1;
endmodule

module m13b_leaf(input logic [7:0] v);
  logic [7:0] data;
  assign data = v + 1;
endmodule

module m13b_mid(input logic [7:0] v);
  m13b_leaf u_a(.v(v));
  m13b_leaf u_b(.v(v));
endmodule

module m13b_bind_instance_test;
  logic [7:0] x = 8'd41;
  m13b_mid m1(.v(x));
  m13b_mid m2(.v(x));

  initial begin
    #3;
    if (m13b_bind_cnt_pkg::c_path == 1
        && m13b_bind_cnt_pkg::c_list == 2
        && m13b_bind_cnt_pkg::c_def == 4)
      $display("PASS: bind-to-instance (path=%0d list=%0d def=%0d)",
               m13b_bind_cnt_pkg::c_path,
               m13b_bind_cnt_pkg::c_list,
               m13b_bind_cnt_pkg::c_def);
    else
      $display("FAIL: bind counts path=%0d (want 1) list=%0d (want 2) def=%0d (want 4)",
               m13b_bind_cnt_pkg::c_path,
               m13b_bind_cnt_pkg::c_list,
               m13b_bind_cnt_pkg::c_def);
    $finish(0);
  end
endmodule

// Only inside the one named instance.
bind m13b_bind_instance_test.m1.u_a m13b_checker_path cp(.d(data));
// Any instance of m13b_leaf named u_b (one in each mid).
bind m13b_leaf : u_b m13b_checker_list cl(.d(data));
// Every instance of m13b_leaf (pre-existing definition bind).
bind m13b_leaf m13b_checker_def cd(.d(data));
