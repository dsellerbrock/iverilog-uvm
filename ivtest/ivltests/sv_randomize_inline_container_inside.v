// An unpacked-array operand of inside denotes its elements (IEEE
// 1800-2017/2023 11.4.13), including a queue-valued expression such as an
// associative-array entry, in inline class constraints and in scope
// randomization of a class property (18.7, 18.12). OpenTitan
// lc_ctrl_smoke_vseq.sv: next_lc_state inside {VALID_NEXT_STATES[state]};
// lc_ctrl_errors_vseq.sv: a 320-bit lc_state inside {LcValidStateForTrans},
// a package const dynamic array.
package next_pkg;
  typedef enum logic [4:0] { S0, S1, S2, S3, S4, S5, S6 } st_e;
  const st_e NEXT [st_e][$] = '{
    S0: {S1, S2, S3},
    S3: {S4, S6},
    S5: {S6}
  };
  typedef enum logic [319:0] {
    WA = {64'hDEAD_BEEF_0000_0001, 256'h1},
    WB = {64'hCAFE_F00D_0000_0002, 256'h2},
    WC = 320'h3,
    WD = {64'h1, 256'h4}
  } wide_e;
  const wide_e VALID_WIDE [] = '{WB, WD};
endpackage
import next_pkg::*;

class item;
  rand st_e nxt;
endclass

class seq;
  st_e nxt;
  st_e cnt;
  int local_q [$];
  wide_e wide_state;
  logic [319:0] wide_q [$];

  function bit wide_scope_pick();
    return std::randomize(wide_state) with { wide_state inside {VALID_WIDE}; };
  endfunction

  function bit wide_local_pick(output logic [319:0] v);
    wide_q = '{WA, WC};
    return std::randomize(v) with { !(v inside {wide_q}); v inside {WA, WB, WC}; };
  endfunction

  function bit scope_pick(st_e cur);
    return std::randomize(nxt) with {
      nxt inside {NEXT[cur]};
      if (cnt == S6) nxt == S6;
    };
  endfunction

  function bit inline_pick(item it, st_e cur);
    return it.randomize() with { nxt inside {NEXT[cur]}; };
  endfunction

  function bit local_queue_pick(item it);
    local_q = '{2, 4};
    return it.randomize() with { !(nxt inside {local_q}); nxt < S5; };
  endfunction
endclass

module test;
  seq s = new;
  item it = new;
  bit failed = 0;
  int hits [7];
  int wide_b = 0;
  logic [319:0] wv;

  task automatic check(string what, bit ok);
    if (!ok) begin
      $display("FAILED %s", what);
      failed = 1;
    end
  endtask

  initial begin
    s.cnt = S0;
    repeat (40) begin
      check("scope entry S0", s.scope_pick(S0) && s.nxt inside {S1, S2, S3});
      hits[s.nxt]++;
      check("scope entry S3", s.scope_pick(S3) && s.nxt inside {S4, S6});
      check("scope entry S5", s.scope_pick(S5) && s.nxt == S6);
      check("inline entry", s.inline_pick(it, S3) && it.nxt inside {S4, S6});
      check("inline local queue", s.local_queue_pick(it)
            && it.nxt inside {S0, S1, S3});
    end
    repeat (40) begin
      check("wide const array", s.wide_scope_pick()
            && s.wide_state inside {WB, WD});
      if (s.wide_state == WB) wide_b++;
      check("wide local queue", s.wide_local_pick(wv) && wv === WB);
    end
    check("wide const array spread", wide_b > 5 && wide_b < 35);
    check("scope entry spread", hits[S1] > 3 && hits[S2] > 3 && hits[S3] > 3);
    s.cnt = S6;
    check("guarded entry", s.scope_pick(S3) && s.nxt == S6);
    check("guarded entry conflict", !s.scope_pick(S0));
    if (!failed) $display("PASSED");
  end
endmodule
