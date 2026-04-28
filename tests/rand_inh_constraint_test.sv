// Phase 48: randomize() now walks the class inheritance chain to apply
// constraints declared in base classes on base-class rand fields. The
// previous of_RANDOMIZE only consulted defn->constraint_count() on the
// runtime class itself, so a deeper-derived instance of a class with
// inherited rand+constraint would skip the inherited constraint and
// leave the field with raw rand() bits. OpenTitan UART DV's
// uart_period_glitch_pct (declared with `inside {[0:10]}` constraint in
// uart_base_vseq) was getting unconstrained values >= 1B, tripping the
// uart_agent_cfg pct < 20 fatal at the start of every body().

class A;
  rand bit [31:0] a_x;
  constraint c_ax { a_x inside {[0:10]}; }
endclass

class B extends A;
  rand bit [31:0] b_x;
endclass

class C extends B;
  rand bit [31:0] c_x;
endclass

module top;
  initial begin
    int n_pass = 0;
    int n_fail = 0;
    int i;
    C ch;
    ch = new();
    for (i = 0; i < 10; i++) begin
      void'(ch.randomize());
      if (ch.a_x > 10) n_fail++;
      else n_pass++;
    end
    if (n_fail == 0) $display("PASS %0d/%0d", n_pass, n_pass + n_fail);
    else $display("FAIL %0d failures out of %0d", n_fail, n_pass + n_fail);
    $finish;
  end
endmodule
