module test;
  import "DPI-C" pure function int c_valid(input int x);
  import "DPI-C" pure function int c_output(output int x);
  import "DPI-C" pure function int c_inout(inout int x);
  import "DPI-C" pure function void c_void(input int x);
  import "DPI-C" pure c_a = function int c_alias_out(output int x);
  import "DPI-C" pure c_b = function void c_alias_void(input int x);
  import "DPI-C" context c_c = function void c_ctx_void(input int x);
  import "DPI-C" context c_d = function int c_ctx_out(output int x);
  import "DPI-C" c_e = function void c_plain_void(input int x);
  import "DPI-C" pure c_f = function int c_alias_ok(input int x);
  import "DPI-C" context pure c_g = function void c_context_pure_void(input int x);
  import "DPI-C" pure context c_h = function int c_context_pure_out(output int x);
  import "DPI-C" context function void c_ctx_plain(input int x);
endmodule
