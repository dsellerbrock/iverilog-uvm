// IEEE 1800-2017/2023 18.12/18.7: caller-scope values in randomize() with
// constraints keep their full width. Values wider than 64 bits were
// silently narrowed to their low 32 bits (e.g. OpenTitan 128-bit tokens).
class item;
  rand logic [127:0] x;
endclass

class key_cfg;
  logic [127:0] key = {64'h0123_4567_89AB_CDEF, 64'h0000_0000_0000_0042};
endclass

class state_item;
  localparam logic [127:0] P = {64'h1234_5678_9ABC_DEF0, 64'h11};
  rand logic [127:0] from_state, from_path, from_param;
  logic [127:0] tok = {64'hCAFE_F00D_0000_0002, 64'h7};
  key_cfg cfg = new;
  constraint c_state { from_state == tok; }
  constraint c_path  { from_path == cfg.key; }
  constraint c_param { from_param == P; }
endclass

module test;
  logic [127:0] a = {64'hDEAD_BEEF_0000_0001, 64'h0000_0000_0000_0005};
  logic [127:0] b = {64'hCAFE_F00D_0000_0002, 64'h0000_0000_0000_0007};
  logic [99:0]  c = {36'h9_8765_4321, 64'h1};
  logic [47:0]  a48 = 48'h1234_0000_0005;
  logic [127:0] x;
  logic [99:0]  y;
  logic [47:0]  x48;
  localparam logic [127:0] MP = {64'hFEED_FACE_0000_0003, 64'h22};
  logic [127:0] q[$];
  item it;
  state_item st;
  bit failed = 0;

  task automatic check(string what, bit ok);
    if (!ok) begin
      $display("FAILED %s", what);
      failed = 1;
    end
  endtask

  initial begin
    check("eq", std::randomize(x) with { x == a; } && x === a);
    check("eq 100-bit", std::randomize(y) with { y == c; } && y === c);
    check("eq 48-bit control", std::randomize(x48) with { x48 == a48; } && x48 === a48);
    repeat (16) check("inside",
      std::randomize(x) with { x inside {a, b}; } && (x === a || x === b));
    repeat (16) check("not inside",
      std::randomize(x) with { !(x inside {a, b}); } && x !== a && x !== b);
    check("arith", std::randomize(x) with { x == a + 1; } && x === a + 1);
    it = new;
    check("inline", it.randomize() with { x == b; } && it.x === b);
    check("literal", std::randomize(x) with {
            x == 128'hABCD_0000_0000_0001_0000_0000_0000_0009; }
          && x === 128'hABCD_0000_0000_0001_0000_0000_0000_0009);
    check("module parameter", std::randomize(x) with { x == MP; } && x === MP);
    check("queue elements", std::randomize(q) with {
            q.size() == 2; foreach (q[i]) q[i] == a; }
          && q.size() == 2 && q[0] === a && q[1] === a);
    st = new;
    check("class state", st.randomize() && st.from_state === st.tok
          && st.from_path === st.cfg.key && st.from_param === state_item::P);
    if (!failed) $display("PASSED");
  end
endmodule
