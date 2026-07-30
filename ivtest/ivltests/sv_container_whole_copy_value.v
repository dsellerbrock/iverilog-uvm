// Whole-container assignment must copy by value (IEEE 1800-2017 7.6,
// 7.9.9): a queue/darray assigned to another variable gets its own
// elements. Container-typed and struct-typed elements copy by value;
// class-handle elements stay shared handles. Pre-fix, an object-element
// queue assignment was a raw handle store: source and destination
// aliased at every level, so every mutation-after-copy leaked.
typedef struct {
  int da[];
  string str;
} rec_t;

module main;
  string qq[$][$];
  string q2[$][$];
  int    di[][];
  rec_t  rq[$];
  rec_t  rq2[$];
  string qa[$][string];
  string qa2[$][string];
  int fails = 0;

  class C;
    int x;
    string dq[$][$];
  endclass

  C qc[$];
  C qc2[$];

  initial begin
    // -- queue of queues: independence both directions, sizes too.
    qq.push_back('{"a","b"});
    qq.push_back('{"c"});
    q2 = qq;
    q2[0][0] = "Z";
    if (qq[0][0] != "a") begin fails++; $display("FAILED: dest->src elem leak '%s'", qq[0][0]); end
    qq[1][0] = "Y";
    if (q2[1][0] != "c") begin fails++; $display("FAILED: src->dest elem leak '%s'", q2[1][0]); end
    q2.push_back('{"n"});
    if (qq.size() != 2 || q2.size() != 3) begin fails++; $display("FAILED: outer size %0d %0d", qq.size(), q2.size()); end
    q2[0].push_back("m");
    if (qq[0].size() != 2) begin fails++; $display("FAILED: inner size leak %0d", qq[0].size()); end

    // -- self assignment is harmless.
    qq = qq;
    if (qq.size() != 2 || qq[0][0] != "a" || qq[1][0] != "Y") begin
      fails++; $display("FAILED: self-assign %0d '%s' '%s'", qq.size(), qq[0][0], qq[1][0]);
    end

    // -- darray of darrays through the signal-rvalue dup path.
    di = new[1];
    di[0] = new[2];
    di[0][0] = 5;
    begin
      int d2[][];
      d2 = di;
      d2[0][0] = 77;
      if (di[0][0] != 5) begin fails++; $display("FAILED: darray elem leak %0d", di[0][0]); end
    end

    // -- struct elements copy by value on whole-queue copy.
    begin
      rec_t tmp;
      tmp.da = new[2]; tmp.da[0] = 10; tmp.str = "hello";
      rq.push_back(tmp);
    end
    rq2 = rq;
    rq2[0].str = "mutated";
    if (rq[0].str != "hello") begin fails++; $display("FAILED: struct elem str leak '%s'", rq[0].str); end
    rq2[0].da[0] = 999;
    if (rq[0].da[0] != 10) begin fails++; $display("FAILED: struct elem darray leak %0d", rq[0].da[0]); end
    if (rq2[0].da[0] != 999) begin fails++; $display("FAILED: struct elem darray write %0d", rq2[0].da[0]); end

    // -- class-handle elements: the QUEUE copies, the handles stay shared.
    begin
      C h = new; h.x = 7;
      qc.push_back(h);
      qc2 = qc;
      qc2[0].x = 42;
      if (qc[0].x != 42) begin fails++; $display("FAILED: class handle wrongly deep-copied %0d", qc[0].x); end
      qc2.push_back(h);
      if (qc.size() != 1) begin fails++; $display("FAILED: class queue size leak %0d", qc.size()); end
    end

    // -- property rvalue: whole copy from a class property must copy too.
    begin
      C h = new;
      h.dq.push_back('{"p"});
      q2 = h.dq;
      q2[0][0] = "X";
      if (h.dq[0][0] != "p") begin fails++; $display("FAILED: property rvalue alias '%s'", h.dq[0][0]); end
    end

    // -- assoc elements inside a queue value-copy as well.
    begin
      string am[string];
      am["k"] = "v";
      qa.push_back(am);
      qa2 = qa;
      qa2[0]["k"] = "w";
      if (qa[0]["k"] != "v") begin fails++; $display("FAILED: assoc elem leak '%s'", qa[0]["k"]); end
    end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
