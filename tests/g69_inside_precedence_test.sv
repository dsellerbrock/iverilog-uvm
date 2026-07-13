// G69: the inside operator binds at the relational level (IEEE
// 1800-2017 Table 11-2) — tighter than equality, &&, || and ?:.
// Previously it sat at ternary precedence, so
//   a && b inside {c, d}
// parsed as (a && b) inside {c, d}, which made the UVM sequencer
// zombie predicate match every arbitration entry ((0) inside
// {KILLED, FINISHED=0}).
module g69_inside_precedence_test;
  int errors = 0;
  int status = 1;       // "RUNNING"
  int request = 1;
  bit b;

  task check(string what, bit got, bit exp);
    if (got !== exp) begin
      $display("FAIL %s: got %0d expect %0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    // a && b inside {..}  ==  a && (b inside {..})
    b = (request == 1 && status inside {4, 0});
    check("and-inside false", b, 0);
    b = (request == 1 && status inside {1, 2});
    check("and-inside true", b, 1);
    // mis-parse ((request==1 && status) inside {4,0}) would give 0
    // here too, so pin the case that distinguishes: request!=1 makes
    // the mis-parse evaluate (0 inside {4,0}) == 1.
    request = 0;
    b = (request == 1 && status inside {4, 0});
    check("short-circuit not inside", b, 0);
    request = 1;

    // a == b inside {..}  ==  a == (b inside {..})   (inside binds
    // tighter than equality per Table 11-2)
    b = (1 == status inside {1});      // 1 == (1 inside {1}) = 1
    check("eq-inside", b, 1);
    b = (0 == status inside {2});      // 0 == (1 inside {2}) = 1
    check("eq-not-inside", b, 1);

    // || and ?: still bind looser
    b = (0 || status inside {1});
    check("or-inside", b, 1);
    b = (status inside {1} ? 1 : 0);
    check("ternary-inside", b, 1);

    if (errors == 0) $display("PASS");
    else $display("%0d checks failed", errors);
    $finish;
  end
endmodule
