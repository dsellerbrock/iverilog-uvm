interface intf_d; endinterface
class K; endclass
module p06_08a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  var byte my_byte; var v; var [15:0] vw; var enum bit {clear, error} status;
  shortint s1, s2[0:9];
  logic [3:0] dl; bit [3:0] db; integer dig; int dint; real dr; shortreal dsr; time dt; string ds;
  K dk; chandle dc; event de; enum {EA = 1, EB} den; enum logic [1:0] {EP, EQ} del; virtual intf_d dvi;
  int init_i = 0, init_j = 5, got = 0; K kk = new;
  task automatic tdef(); int a; logic [1:0] l; string s; ck("auto_defaults", a == 0 && l === 2'bx && s == ""); endtask
  initial begin
    ck("var_forms", $bits(my_byte) == 8 && $bits(v) == 1 && $bits(vw) == 16 && $bits(status) == 1);
    ck("var_logic_default", v === 1'bx && vw === 16'bx);
    ck("shared_decl", $size(s2) == 10 && $bits(s1) == 16);
    ck("def_4state", dl === 4'bx && dig === 32'bx && dt === 64'bx);
    ck("def_2state", db == 0 && dint == 0);
    ck("def_real", dr == 0.0 && dsr == 0.0);
    ck("def_string", ds == "" && ds.len() == 0);
    ck("def_handles", dk == null && dc == null && dvi == null);
    fork begin @(de); got = 1; end begin #1; -> de; end join
    ck("def_event", got == 1);
    ck("def_enum_int", int'(den) == 0);
    ck("def_enum_4state", del === 2'bx);
    ck("initializers", init_i == 0 && init_j == 5 && kk != null);
    tdef();
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
