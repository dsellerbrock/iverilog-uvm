// Campaign 6 wave 2 (rand CONTAINER/TYPE correctness cluster) evidence-pass
// regression pin, part 2 of 2: CONSTRAINT-LANGUAGE and randomize()-machinery
// coverage that was found to already WORK but was previously untested --
// pinned here so a future change cannot silently regress it. Objects are
// explicitly srandom()-seeded for reproducibility.
//
// Covers: implication (->) / if-else / foreach constraints together on one
// class, unique{} over both scalars and array elements, solve...before
// (18.5.9) as an ordering hint, inline `with` on randomize() (18.7),
// constraint_mode() (18.9), a 3-level pre_randomize/post_randomize chain
// (18.6.2-18.6.4), and srandom() determinism (18.13.3) for both
// randomize() draws and $urandom_range() calls made from an object method.
module sv_rand_conformance_pin2;

  class ImplC;
    rand bit flag;
    rand int x;
    rand int y;
    rand int arr[];
    constraint c_len    { arr.size() == 5; }
    constraint c_impl   { flag -> (x > 100); (!flag) -> (x <= 100); }
    constraint c_ifelse { if (flag) y == x + 1; else y == x - 1; }
    constraint c_foreach{ foreach (arr[i]) arr[i] == i * 10; }
  endclass

  class UniqScalarC;
    rand bit [3:0] a, b, cc;
    constraint u { unique { a, b, cc }; }
  endclass

  class UniqArrC;
    rand int arr[5];
    constraint c { unique { arr }; foreach (arr[i]) arr[i] inside {[0:9]}; }
  endclass

  class SolveBeforeC;
    rand bit [2:0] p, q;
    constraint order1 { solve p before q; }
    constraint rel     { q > p; }
  endclass

  class CmodeC;
    rand int v;
    constraint cb { v inside {[0:10]}; }
  endclass

  class Base;
    rand int v;
    int pre_calls  = 0;
    int post_calls = 0;
    constraint cb { v inside {[0:10]}; }
    function void pre_randomize();  pre_calls++;  endfunction
    function void post_randomize(); post_calls++; endfunction
  endclass

  class Mid extends Base;
    int mid_pre  = 0;
    int mid_post = 0;
    function void pre_randomize();  super.pre_randomize();  mid_pre++;  endfunction
    function void post_randomize(); super.post_randomize(); mid_post++; endfunction
  endclass

  class Leaf extends Mid;
    int leaf_pre  = 0;
    int leaf_post = 0;
    function void pre_randomize();  super.pre_randomize();  leaf_pre++;  endfunction
    function void post_randomize(); super.post_randomize(); leaf_post++; endfunction
  endclass

  class UrandomC;
    rand int v;
    function int draw_urandom();
      return $urandom_range(0, 999);
    endfunction
  endclass

  int errors = 0;

  initial begin
    // -- implication / if-else / foreach, together --
    begin
      ImplC ic = new();
      int impl_ok = 0, ifelse_ok = 0, foreach_ok = 0;
      ic.srandom(2001);
      for (int i = 0; i < 30; i++) begin
        if (!ic.randomize()) begin $display("FAIL: ImplC randomize()==0"); errors++; continue; end
        if ((ic.flag && ic.x > 100) || (!ic.flag && ic.x <= 100)) impl_ok++;
        if ((ic.flag && ic.y == ic.x+1) || (!ic.flag && ic.y == ic.x-1)) ifelse_ok++;
        begin
          bit fok = 1;
          foreach (ic.arr[k]) if (ic.arr[k] != k*10) fok = 0;
          if (fok) foreach_ok++;
        end
      end
      if (impl_ok != 30)    begin $display("FAIL: implication ok=%0d/30", impl_ok);    errors++; end
      if (ifelse_ok != 30)  begin $display("FAIL: if-else ok=%0d/30", ifelse_ok);      errors++; end
      if (foreach_ok != 30) begin $display("FAIL: foreach ok=%0d/30", foreach_ok);     errors++; end
    end

    // -- unique{} over scalars --
    begin
      UniqScalarC sc = new();
      int distinct = 0;
      sc.srandom(2002);
      for (int i = 0; i < 30; i++) begin
        if (!sc.randomize()) begin $display("FAIL: UniqScalarC randomize()==0"); errors++; continue; end
        if (sc.a != sc.b && sc.b != sc.cc && sc.a != sc.cc) distinct++;
      end
      if (distinct != 30) begin $display("FAIL: unique{} scalars distinct=%0d/30", distinct); errors++; end
    end

    // -- unique{} over array elements --
    begin
      UniqArrC ac = new();
      int distinct = 0;
      ac.srandom(2003);
      for (int i = 0; i < 30; i++) begin
        if (!ac.randomize()) begin $display("FAIL: UniqArrC randomize()==0"); errors++; continue; end
        begin
          bit dup = 0;
          for (int a = 0; a < 5; a++)
            for (int b = a+1; b < 5; b++)
              if (ac.arr[a] == ac.arr[b]) dup = 1;
          if (!dup) distinct++;
        end
      end
      if (distinct != 30) begin $display("FAIL: unique{} array distinct=%0d/30", distinct); errors++; end
    end

    // -- solve...before + inline `with` --
    begin
      SolveBeforeC d = new();
      int ok = 0;
      d.srandom(2004);
      for (int i = 0; i < 30; i++) begin
        if (!d.randomize()) begin $display("FAIL: SolveBeforeC randomize()==0"); errors++; continue; end
        if (d.q > d.p) ok++;
      end
      if (ok != 30) begin $display("FAIL: solve-before ok=%0d/30", ok); errors++; end

      begin
        SolveBeforeC d2 = new();
        int with_ok = 0;
        d2.srandom(2005);
        for (int i = 0; i < 30; i++) begin
          if (!(d2.randomize() with { p == 2; })) begin
            $display("FAIL: inline-with randomize()==0"); errors++; continue;
          end
          if (d2.p == 2 && d2.q > 2) with_ok++;
        end
        if (with_ok != 30) begin $display("FAIL: inline-with ok=%0d/30", with_ok); errors++; end
      end
    end

    // -- constraint_mode() --
    begin
      CmodeC b = new();
      int seen_violation = 0;
      b.srandom(2006);
      b.constraint_mode(0); // disable the [0:10] range constraint
      for (int i = 0; i < 10; i++) begin
        void'(b.randomize() with { v == 500; }); // out of [0:10]; only legal with cb off
        if (b.v == 500) seen_violation++;
      end
      if (seen_violation != 10) begin
        $display("FAIL: constraint_mode(0) did not free v: seen=%0d/10", seen_violation);
        errors++;
      end

      b.constraint_mode(1); // re-enable
      if (b.randomize() with { v == 500; }) begin
        $display("FAIL: constraint_mode(1) should make v==500 UNSAT (outside [0:10])");
        errors++;
      end
    end

    // -- 3-level pre_randomize/post_randomize chain --
    begin
      Leaf l = new();
      if (!l.randomize()) begin $display("FAIL: Leaf randomize()==0"); errors++; end
      if (!(l.pre_calls==1 && l.post_calls==1 && l.mid_pre==1 && l.mid_post==1
            && l.leaf_pre==1 && l.leaf_post==1)) begin
        $display("FAIL: pre/post_randomize chain counts wrong: pre=%0d post=%0d mid_pre=%0d mid_post=%0d leaf_pre=%0d leaf_post=%0d",
                  l.pre_calls, l.post_calls, l.mid_pre, l.mid_post, l.leaf_pre, l.leaf_post);
        errors++;
      end
    end

    // -- srandom() determinism: randomize() sequence AND $urandom_range() --
    begin
      UrandomC c1 = new(), c2 = new(), c3 = new();
      int seq1[5], seq2[5];
      int u1[5], u2[5];
      c1.srandom(42);
      c2.srandom(42);
      for (int i = 0; i < 5; i++) begin
        void'(c1.randomize()); seq1[i] = c1.v; u1[i] = c1.draw_urandom();
      end
      for (int i = 0; i < 5; i++) begin
        void'(c2.randomize()); seq2[i] = c2.v; u2[i] = c2.draw_urandom();
      end
      begin
        bit match_v = 1, match_u = 1;
        foreach (seq1[i]) if (seq1[i] != seq2[i]) match_v = 0;
        foreach (u1[i])   if (u1[i]   != u2[i])   match_u = 0;
        if (!match_v) begin $display("FAIL: srandom(42) randomize() sequence not reproducible"); errors++; end
        if (!match_u) begin $display("FAIL: srandom(42) $urandom_range sequence not reproducible"); errors++; end
      end

      c3.srandom(43);
      begin
        int diverged = 0;
        for (int i = 0; i < 5; i++) begin
          void'(c3.randomize());
          if (c3.v != seq1[i]) diverged++;
        end
        if (diverged == 0) begin
          $display("FAIL: srandom(43) failed to diverge from srandom(42) at all");
          errors++;
        end
      end
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d)", errors);
  end
endmodule
