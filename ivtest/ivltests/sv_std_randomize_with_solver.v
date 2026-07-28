// IEEE 1800-2017 18.12: std::randomize(vars) with { constraints }.
//
// This is deliberately discriminating against the former implementation:
// the statement form used parser-time range/enum/retry heuristics, while the
// expression form randomized unconstrained values and always returned 1.
module sv_std_randomize_with_solver;
  int a, b;
  int limit;
  logic signed [7:0] s8;
  logic [15:0] u16;
  logic [63:0] u64;
  typedef enum logic [1:0] { E_ZERO = 0, E_TWO = 2 } e_t;
  e_t ev;
  int errors = 0;

  task automatic check_automatic_local;
    int local_v = 0;
    if (!std::randomize(local_v) with { local_v == 31415; }) begin
      $display("FAIL automatic-local SAT returned 0");
      errors++;
    end else if (local_v != 31415) begin
      $display("FAIL automatic-local write-back: local_v=%0d", local_v);
      errors++;
    end
  endtask

  initial begin
    // Cross-variable and exact-value constraints cannot be implemented by
    // independently choosing a range for each argument.
    a = 0;
    b = 0;
    std::randomize(a, b) with {
      a == 13;
      b == 29;
      a + b == 42;
    };
    if (a != 13 || b != 29) begin
      $display("FAIL statement solve: a=%0d b=%0d", a, b);
      errors++;
    end

    check_automatic_local();

    // The uint64 model/write-back boundary must not truncate through the
    // former 32-bit system-function path.
    u64 = 0;
    if (!std::randomize(u64) with {
      u64 == 64'hfedc_ba98_7654_3210;
    }) begin
      $display("FAIL 64-bit SAT returned 0");
      errors++;
    end else if (u64 != 64'hfedc_ba98_7654_3210) begin
      $display("FAIL 64-bit write-back: u64=%h", u64);
      errors++;
    end

    // Enum literals resolve in the caller scope while the enum variable is
    // still a solver destination.
    ev = E_ZERO;
    if (!std::randomize(ev) with { ev == E_TWO; }) begin
      $display("FAIL enum SAT returned 0");
      errors++;
    end else if (ev != E_TWO) begin
      $display("FAIL enum write-back: ev=%0d", ev);
      errors++;
    end

    // The void-cast task spelling must preserve and enforce the same AST.
    a = 0;
    void'(std::randomize(a) with { a == 91; });
    if (a != 91) begin
      $display("FAIL void-cast statement solve: a=%0d", a);
      errors++;
    end

    // The expression form must use the same solver and return its status.
    limit = 31;
    a = 0;
    if (!std::randomize(a) with {
      a > limit;
      a < limit + 3;
    }) begin
      $display("FAIL expression SAT returned 0");
      errors++;
    end else if (a <= limit || a >= limit + 3) begin
      $display("FAIL expression solve: a=%0d limit=%0d", a, limit);
      errors++;
    end

    // A caller-scope state variable used as an inside-set member is a
    // runtime constant, not a class-property lookup.
    limit = 44;
    a = 0;
    if (!std::randomize(a) with { a inside {limit}; }) begin
      $display("FAIL state-set SAT returned 0");
      errors++;
    end else if (a != limit) begin
      $display("FAIL state-set solve: a=%0d limit=%0d", a, limit);
      errors++;
    end

    // Conditional and soft forms use the shared constraint IR semantics.
    limit = 1;
    a = 0;
    if (!std::randomize(a) with {
      if (limit) a inside {[0:10]}; else a == 99;
      soft a == 7;
    }) begin
      $display("FAIL conditional/soft SAT returned 0");
      errors++;
    end else if (a != 7) begin
      $display("FAIL conditional/soft solve: a=%0d", a);
      errors++;
    end

    // Width and signedness are part of the random-variable identity.
    s8 = 0;
    u16 = 0;
    if (!std::randomize(s8, u16) with {
      s8 inside {[-7:-3]};
      u16 == 16'hbabe;
    }) begin
      $display("FAIL narrow SAT returned 0");
      errors++;
    end else begin
      if (s8 < -7 || s8 > -3) begin
        $display("FAIL signed width: s8=%0d", s8);
        errors++;
      end
      if (u16 != 16'hbabe) begin
        $display("FAIL unsigned width: u16=%h", u16);
        errors++;
      end
    end

    // An unsatisfiable call returns 0 and preserves every destination.
    a = 77;
    b = -19;
    if (std::randomize(a, b) with {
      a == 1;
      a == 2;
      b == 3;
    }) begin
      $display("FAIL UNSAT returned 1");
      errors++;
    end
    if (a != 77 || b != -19) begin
      $display("FAIL UNSAT changed destinations: a=%0d b=%0d", a, b);
      errors++;
    end

    // Discarding the result in statement position does not permit an
    // unsatisfiable call to overwrite the destination.
    a = 1234;
    std::randomize(a) with { a == 4; a == 5; };
    if (a != 1234) begin
      $display("FAIL statement UNSAT changed destination: a=%0d", a);
      errors++;
    end

    // The unconstrained sibling remains a working control.
    a = 0;
    if (!std::randomize(a)) begin
      $display("FAIL unconstrained control returned 0");
      errors++;
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED (%0d)", errors);
  end
endmodule
