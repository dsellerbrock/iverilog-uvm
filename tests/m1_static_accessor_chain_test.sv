// M1 typed-expression dispatch: singleton/static accessor patterns
// C::get().method(), C::get().prop, and parameterized
// C#(T)::get().method(), in expression and statement contexts
// (IEEE 1800-2017 8.10, 8.23, 8.25). Reduced from gap audit G22
// (uvm_factory::get().create_object_by_name).
module m1_static_accessor_chain_test;
  int stmt_hits = 0;

  class S;
    static S inst;
    int v = 5;
    static function S get();
      if (inst == null) inst = new;
      return inst;
    endfunction
    function int get_v();
      return v;
    endfunction
    function void poke();
      stmt_hits = stmt_hits + 1;
    endfunction
    task do_work(int n);
      #1 stmt_hits = stmt_hits + n;
    endtask
  endclass

  class P #(type T = int);
    static P #(T) inst;
    T val;
    static function P#(T) get();
      if (inst == null) inst = new;
      return inst;
    endfunction
    function int size_of();
      return $bits(val);
    endfunction
  endclass

  initial begin
    int errors = 0;

    // Static accessor + method call (expression).
    if (S::get().get_v() !== 5) begin
      $display("FAIL: S::get().get_v() = %0d, expected 5", S::get().get_v());
      errors++;
    end

    // Static accessor + property access.
    if (S::get().v !== 5) begin
      $display("FAIL: S::get().v = %0d, expected 5", S::get().v);
      errors++;
    end

    // Parameterized specialization accessor + method call.
    if (P#(byte)::get().size_of() !== 8) begin
      $display("FAIL: P#(byte)::get().size_of() = %0d, expected 8",
               P#(byte)::get().size_of());
      errors++;
    end
    if (P#(shortint)::get().size_of() !== 16) begin
      $display("FAIL: P#(shortint)::get().size_of() = %0d, expected 16",
               P#(shortint)::get().size_of());
      errors++;
    end

    // Statement form: void method on static accessor result.
    S::get().poke();
    if (stmt_hits !== 1) begin
      $display("FAIL: S::get().poke(); ran %0d times, expected 1", stmt_hits);
      errors++;
    end

    // Statement form: TASK on static accessor result (consumes time).
    S::get().do_work(5);
    if (stmt_hits !== 6) begin
      $display("FAIL: S::get().do_work(5); stmt_hits=%0d, expected 6", stmt_hits);
      errors++;
    end

    if (errors == 0) $display("PASS");
    $finish;
  end
endmodule
