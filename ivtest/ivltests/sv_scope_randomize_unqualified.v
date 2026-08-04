// IEEE 1800-2017 18.12, Syntax 18-11: the `std::` prefix on the scope
// randomize function is optional. Exercise both discarded-return statement
// calls (as used by OpenTitan prim_present) and expression calls, including
// values wider than the 32-bit random-number system functions. Also pin the
// lookup boundary: ordinary user subroutines retain lexical precedence, while
// a bare randomize() inside a class remains the built-in object method.
module scope_randomize_function_shadow(
  output bit done,
  output bit failed
);
  bit [7:0] value;

  function automatic int randomize(input bit [7:0] arg);
    return 37 + arg;
  endfunction

  initial begin
    value = 5;
    if (randomize(value) != 42) begin
      $display("FAIL: user function named randomize did not shadow scope randomize");
      failed = 1;
    end
    done = 1;
  end
endmodule

module scope_randomize_task_shadow(
  output bit done,
  output bit failed
);
  bit [7:0] value;
  int calls;

  task automatic randomize(input bit [7:0] arg);
    calls += arg;
  endtask

  initial begin
    value = 3;
    randomize(value);
    if (calls != 3) begin
      $display("FAIL: user task named randomize did not shadow scope randomize");
      failed = 1;
    end
    done = 1;
  end
endmodule

class scope_randomize_class_probe;
  rand bit [7:0] value;
  constraint exact_value { value == 8'h5a; }

  function automatic bit run_expression;
    value = '0;
    return randomize() && value == 8'h5a;
  endfunction

  task automatic run_statement(output bit failed);
    value = '0;
    void'(randomize());
    failed = value != 8'h5a;
  endtask
endclass

module scope_randomize_class_preservation(
  output bit done,
  output bit failed
);
  scope_randomize_class_probe probe;
  bit statement_failed;

  initial begin
    probe = new;
    if (!probe.run_expression()) begin
      $display("FAIL: bare class expression did not use object randomize");
      failed = 1;
    end
    probe.run_statement(statement_failed);
    if (statement_failed) begin
      $display("FAIL: bare class statement did not use object randomize");
      failed = 1;
    end
    done = 1;
  end
endmodule

module sv_scope_randomize_unqualified;
  bit [63:0] plaintext;
  bit [127:0] key;
  int errors = 0;
  bit saw_plaintext_upper = 0;
  bit saw_key_upper = 0;
  bit function_done, function_failed;
  bit task_done, task_failed;
  bit class_done, class_failed;

  scope_randomize_function_shadow function_shadow(
    .done(function_done), .failed(function_failed));
  scope_randomize_task_shadow task_shadow(
    .done(task_done), .failed(task_failed));
  scope_randomize_class_preservation class_preservation(
    .done(class_done), .failed(class_failed));

  initial begin
    for (int i = 0; i < 16; i++) begin
      plaintext = '0;
      key = '0;

      randomize(plaintext);
      if (!randomize(key)) begin
        $display("FAIL: unqualified scope randomize returned 0");
        errors++;
      end

      saw_plaintext_upper |= |plaintext[63:32];
      saw_key_upper |= |key[127:32];
    end

    if (!saw_plaintext_upper) begin
      $display("FAIL: statement randomize did not write bits above bit 31");
      errors++;
    end
    if (!saw_key_upper) begin
      $display("FAIL: expression randomize did not write bits above bit 31");
      errors++;
    end

    wait (function_done && task_done && class_done);
    if (function_failed || task_failed || class_failed)
      errors++;

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED (%0d)", errors);
  end
endmodule
