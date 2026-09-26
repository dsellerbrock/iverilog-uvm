// An unpacked-array operand of inside denotes its elements (IEEE
// 1800-2017/2023 11.4.13), including a queue-valued expression such as an
// associative-array entry, in inline class constraints and in scope
// randomization of a class property (18.7, 18.12). OpenTitan
// lc_ctrl_smoke_vseq.sv: next_lc_state inside {VALID_NEXT_STATES[state]}.
package next_pkg;
  typedef enum logic [4:0] { S0, S1, S2, S3, S4, S5, S6 } st_e;
  const st_e NEXT [st_e][$] = '{
    S0: {S1, S2, S3},
    S3: {S4, S6},
    S5: {S6}
  };
endpackage
import next_pkg::*;

class item;
  rand st_e nxt;
endclass

class seq;
  st_e nxt;
  st_e cnt;
  int local_q [$];

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
    check("scope entry spread", hits[S1] > 3 && hits[S2] > 3 && hits[S3] > 3);
    s.cnt = S6;
    check("guarded entry", s.scope_pick(S3) && s.nxt == S6);
    check("guarded entry conflict", !s.scope_pick(S0));
    if (!failed) $display("PASSED");
  end
endmodule
