module sv_randsequence_recursive;
  timeunit 1ns;
  timeprecision 1ns;

  int background_ticks;
  bit completed;
  logic [3:0] driven = 0, observed;

  always_comb begin
    int remaining;
    remaining = 2;
    randsequence (walk)
      walk : { observed = driven + remaining; remaining--; }
             if (remaining > 0) walk;
    endsequence
  end

  task automatic check_mutual();
    int depth = 0, visits = 0, tails = 0;
    randsequence (a)
      a : { visits++; } if (depth < 3) b { tails = tails * 10 + 1; };
      b : { depth++; } a { tails = tails * 10 + 2; } := 1
        | { $fatal(1, "selected a zero-weight recursive rule"); } := 0;
      // Unsupported forms in unreachable productions are irrelevant here.
      int unused(int value) : unused(value) { return value; };
    endsequence
    if (depth !== 3 || visits !== 4 || tails !== 1212121)
      $fatal(1, "mutual recursion depth=%0d visits=%0d tails=%0d",
             depth, visits, tails);
  endtask

  task automatic check_exits();
    int entries, loops, tails, returns, cutoff, limit;
    int after_sequence = 0;
    for (int pass = 0; pass < 2; pass++) begin
      entries = 0;
      loops = 0;
      tails = 0;
      returns = 0;
      cutoff = pass ? 0 : 16;
      limit = pass ? 2 : 16;
      randsequence (a)
        a : {
              repeat (3) begin
                loops++;
                break;
              end
              entries++;
              if (entries == cutoff) break;
            }
            case (entries < limit)
              1: descend;
              default: stop_here;
            endcase
            { tails++; };
        descend : repeat (2) a { tails++; };
        stop_here : {
          repeat (3) begin
            returns++;
            return;
          end
          $fatal(1, "production return fell through");
        };
      endsequence
      after_sequence++;
      if (loops !== entries)
        $fatal(1, "procedural loop break failed, loops=%0d entries=%0d", loops, entries);
      if (pass == 0 && (entries !== 16 || tails !== 0 || returns !== 0))
        $fatal(1, "sequence break failed, entries=%0d tails=%0d returns=%0d",
               entries, tails, returns);
      if (pass == 1 && (entries !== 3 || tails !== 4 || returns !== 2))
        $fatal(1, "production return failed, entries=%0d tails=%0d returns=%0d",
               entries, tails, returns);
    end
    if (after_sequence !== 2) $fatal(1, "sequence break escaped the statement");
  endtask

  task automatic check_process(input int id);
    process owner = process::self();
    int unsigned expected[0:4];
    int seed = 291 + id;
    int value = 100 * id;
    int initial_value = value;
    int visits = 0;
    int tails = 0;
    time started = $time;

    owner.srandom(seed);
    for (int i = 0; i <= id + 2; i++) expected[i] = $urandom;
    owner.srandom(seed);
    randsequence (walk)
      void walk() : {
        if (process::self() != owner) $fatal(1, "production changed the process");
        if ($urandom !== expected[visits]) $fatal(1, "production changed the RNG stream");
        visits++;
        value += id;
        #1;
        value += id;
        if (id == 1 && visits == id + 2) break;
      } if (visits < id + 2) walk() { tails++; };
    endsequence
    if (visits !== id + 2 || tails !== (id == 1 ? 0 : visits) ||
        value !== initial_value + 2 * id * visits)
      $fatal(1, "automatic task %0d lost its activation", id);
    if ($time !== started + visits) $fatal(1, "recursive calls lost their timing");
    if ($urandom !== expected[visits]) $fatal(1, "post-sequence RNG state differed");
  endtask

  function automatic int sum(input int len);
    int result = 0;
    randsequence (walk)
      walk : { if (len == 0) return; result += len; len--; }
             walk { result++; };
    endsequence
    return result;
  endfunction

  function automatic void spawn_walker();
    int remaining = 2;
    fork
      randsequence (walk)
        walk : { #1; background_ticks++; remaining--; } if (remaining > 0) walk;
      endsequence
    join_none
  endfunction

  initial begin
    check_mutual();
    check_exits();
    if (sum(4) !== 14 || sum(3) !== 9) $fatal(1, "recursive function result");
    spawn_walker();
    fork
      check_process(1);
      check_process(2);
      begin
        #1;
        if (observed !== 1) $fatal(1, "recursive always_comb initial value");
        driven = 4;
        #1;
        if (observed !== 5) $fatal(1, "recursive always_comb sensitivity");
      end
    join
    if ($time !== 4 || background_ticks !== 2)
      $fatal(1, "forked function branch did not run its timed productions");
    completed = 1;
  end

  final begin
    int remaining, tails;
    remaining = 3;
    tails = 0;
    randsequence (walk)
      walk : { remaining--; } if (remaining > 0) walk { tails++; };
    endsequence
    if (!completed || remaining !== 0 || tails !== 3) $fatal(1, "recursive final result");
    $display("PASS");
  end
endmodule
