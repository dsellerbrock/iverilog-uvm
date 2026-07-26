// M3B: soft-constraint PRIORITY (IEEE 1800-2017 18.5.14.1).
//
// Soft constraints are prioritised, not weighted: when two of them
// conflict, the later-declared one wins outright, and a derived class's
// soft outranks its base's. Icarus summed every soft preference into one
// weighted Z3 objective, so a conflict between two soft constraints was
// settled arbitrarily -- `soft v == 3; soft v == 200;' produced v == 3.
//
// Each soft-keyword constraint now becomes its own lexicographic
// objective, applied highest-priority first, and the compiler emits an
// inherited constraint list in ascending declaration order (base blocks
// before the class's own) so list position IS priority.
//
// Against the pre-fix simulator cases 1, 2 and 3 all printed v=3.

class two_in_one_block;
  rand bit [7:0] v;
  constraint c { soft v == 3; soft v == 200; }
endclass

class two_blocks;
  rand bit [7:0] v;
  constraint c1 { soft v == 3; }
  constraint c2 { soft v == 200; }
endclass

class soft_base;
  rand bit [7:0] v;
  constraint s { soft v == 3; }
endclass
class soft_derived extends soft_base;
  constraint d { soft v == 200; }
endclass

// A third conflicting soft: the last one still wins outright, and no
// combination of the earlier two can outvote it.
class three_softs;
  rand bit [7:0] v;
  constraint c1 { soft v == 3; }
  constraint c2 { soft v == 3; }
  constraint c3 { soft v == 200; }
endclass

// Non-conflicting soft constraints must all hold.
class disjoint_softs;
  rand bit [7:0] v, w;
  constraint c { soft v == 7; soft w == 9; }
endclass

// A hard constraint always beats every soft, whatever the priorities.
class hard_wins;
  rand bit [7:0] v;
  constraint c1 { soft v == 3; }
  constraint c2 { soft v == 200; }
  constraint c3 { v > 220; }
endclass

module main;

  two_in_one_block a;
  two_blocks       b;
  soft_derived     c;
  three_softs      d;
  disjoint_softs   e;
  hard_wins        f;

  int fails = 0;
  int ok;

  initial begin
    a = new(); b = new(); c = new(); d = new(); e = new(); f = new();

    for (int i = 0; i < 10; i++) begin
      ok = a.randomize();
      if (!ok || a.v != 200) begin
        fails++;
        $display("FAILED 1 -- two softs in one block: ok=%0d v=%0d (want 200)", ok, a.v);
      end

      ok = b.randomize();
      if (!ok || b.v != 200) begin
        fails++;
        $display("FAILED 2 -- two soft blocks: ok=%0d v=%0d (want 200)", ok, b.v);
      end

      ok = c.randomize();
      if (!ok || c.v != 200) begin
        fails++;
        $display("FAILED 3 -- derived soft over base soft: ok=%0d v=%0d (want 200)", ok, c.v);
      end

      ok = d.randomize();
      if (!ok || d.v != 200) begin
        fails++;
        $display("FAILED 4 -- last of three softs: ok=%0d v=%0d (want 200)", ok, d.v);
      end

      ok = e.randomize();
      if (!ok || e.v != 7 || e.w != 9) begin
        fails++;
        $display("FAILED 5 -- disjoint softs: ok=%0d v=%0d (want 7) w=%0d (want 9)",
                 ok, e.v, e.w);
      end

      ok = f.randomize();
      if (!ok || f.v <= 220) begin
        fails++;
        $display("FAILED 6 -- hard over soft: ok=%0d v=%0d (want >220)", ok, f.v);
      end

      if (fails > 0) break;
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
