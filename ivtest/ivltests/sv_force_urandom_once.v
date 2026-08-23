module sv_force_urandom_once;
  logic [31:0] dst;
  logic [31:0] forced_value;
  logic [31:0] next_after_force;
  logic [31:0] expected_first;
  logic [31:0] expected_next;
  string state_after_force;
  string expected_state_after_first;

  initial begin
    automatic process self_process = process::self();

    // Compare two executions from the same process seed instead of assuming
    // any implementation-specific random-number values. With no RHS variable
    // dependencies, the force expression is evaluated exactly once when the
    // statement becomes active.
    self_process.srandom(32'h1800_2023);
    force dst = $urandom();
    #0 forced_value = dst;
    state_after_force = self_process.get_randstate();

    dst = ~forced_value;
    #0;
    if (dst !== forced_value) begin
      $display("FAILED forced value changed after procedural write");
      $finish;
    end
    #1;
    if (dst !== forced_value) begin
      $display("FAILED no-dependency RHS was reevaluated spontaneously");
      $finish;
    end

    release dst;
    #0;
    if (dst !== forced_value) begin
      $display("FAILED release did not retain the forced variable value");
      $finish;
    end
    next_after_force = $urandom();

    self_process.srandom(32'h1800_2023);
    expected_first = $urandom();
    expected_state_after_first = self_process.get_randstate();
    expected_next = $urandom();
    if (forced_value !== expected_first ||
        next_after_force !== expected_next ||
        state_after_force != expected_state_after_first) begin
      $display("FAILED force consumed an unexpected number of RNG draws");
      $finish;
    end

    $display("PASSED");
  end
endmodule
