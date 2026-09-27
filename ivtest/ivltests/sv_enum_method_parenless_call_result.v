// A zero-argument enumeration method may omit its parentheses on a function
// call result (IEEE 1800-2017/2023 6.19.5, 13.4.2):
// `seq.get_sequence_state().name' (OpenTitan entropy_src).
typedef enum { IDLE, BODY, DONE } state_e;
class seq;
  state_e st = BODY;
  function state_e get_state(); return st; endfunction
endclass
module test;
  initial begin
    automatic seq s = new;
    string a, b;
    state_e n;
    a = s.get_state().name;
    b = s.get_state().name();
    n = s.get_state().next;
    if (a == "BODY" && b == "BODY" && n == DONE) $display("PASSED");
    else $display("FAILED %s %s %s", a, b, n.name);
  end
endmodule
