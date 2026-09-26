// A randomized enum takes only its declared literals (IEEE 1800-2017/2023
// 18.4), whatever its width and whichever randomize form reaches it:
// scope randomize with and without a with-clause (18.12), a class property
// named by scope randomize or by an argument list (18.11), and a rand
// class property, and enum elements of fixed arrays, dynamic arrays, and
// queues, including constrained elements the solver models. OpenTitan lc_ctrl_base_vseq.sv randomizes a 320-bit
// lc_state_e with std::randomize(lc_state).
typedef enum logic [319:0] {
  WA = {64'hDEAD_BEEF_0000_0001, 256'h1},
  WB = {64'hCAFE_F00D_0000_0002, 256'h2},
  WC = 320'h3
} wide_e;
typedef enum logic [15:0] { N0 = 16'h1234, N1 = 16'h5678, N2 = 16'h9ABC } narrow_e;

class holder;
  wide_e st;          // not rand: made random by the call form
  narrow_e cnt;
  rand wide_e rw;
  rand narrow_e rarr [2];
  wide_e plain;
  rand narrow_e rq [$];
  rand wide_e rd [];
  constraint c_sizes { rq.size() == 3; rd.size() == 2; }
  constraint c_elems { rarr[0] != N0; rq[1] != N1; rd[0] != WA; }

  function bit scope_forms(output bit in_domain);
    bit ok = std::randomize(st);
    ok &= std::randomize(cnt) with { (st != WC) -> (cnt != N0); };
    in_domain = (st inside {WA, WB, WC}) && (cnt inside {N0, N1, N2})
                && ((st != WC) -> (cnt != N0));
    return ok;
  endfunction
endclass

module test;
  wide_e w;
  narrow_e n;
  narrow_e sq [$];
  holder h = new;
  int hits_w [3], hits_n [3];
  bit failed = 0, in_domain;

  task automatic check(string what, bit ok);
    if (!ok) begin
      $display("FAILED %s", what);
      failed = 1;
    end
  endtask

  function automatic int wide_index(wide_e v);
    return v == WA ? 0 : v == WB ? 1 : v == WC ? 2 : -1;
  endfunction

  initial begin
    repeat (60) begin
      std::randomize(w);
      check("wide statement form", wide_index(w) >= 0);
      if (wide_index(w) >= 0) hits_w[wide_index(w)]++;
      check("narrow expression form", std::randomize(n) && n inside {N0, N1, N2});
      if (n inside {N0, N1, N2}) hits_n[n == N0 ? 0 : n == N1 ? 1 : 2]++;
      check("wide with-clause", std::randomize(w) with { w != WC; } && w inside {WA, WB});
      check("narrow with-clause", std::randomize(n) with { n != N1; } && n inside {N0, N2});
      check("class scope forms", h.scope_forms(in_domain) && in_domain);
      check("rand class properties", h.randomize()
            && h.rw inside {WA, WB, WC}
            && h.rarr[0] inside {N1, N2} && h.rarr[1] inside {N0, N1, N2});
      check("container elements", h.rq.size() == 3 && h.rd.size() == 2
            && h.rq[0] inside {N0, N1, N2} && h.rq[1] inside {N0, N2}
            && h.rq[2] inside {N0, N1, N2}
            && h.rd[0] inside {WB, WC} && h.rd[1] inside {WA, WB, WC});
      check("scope queue elements", std::randomize(sq) with { sq.size() == 4; }
            && sq.size() == 4
            && sq[0] inside {N0, N1, N2} && sq[1] inside {N0, N1, N2}
            && sq[2] inside {N0, N1, N2} && sq[3] inside {N0, N1, N2});
      check("argument-list non-rand property", h.randomize(plain)
            && h.plain inside {WA, WB, WC});
    end
    foreach (hits_w[i]) check("wide spread", hits_w[i] > 5);
    foreach (hits_n[i]) check("narrow spread", hits_n[i] > 5);
    check("no wide literal satisfies", !std::randomize(w) with { w == 320'h99; });
    check("no narrow literal satisfies", !std::randomize(n) with { n > N2; });
    if (!failed) $display("PASSED");
  end
endmodule
