// A factory-like early use of a parameterized class must preserve builtin
// class property types while its method bodies are elaborated.  In
// particular, semaphore/mailbox/process may not be temporarily treated as
// integers and have their method calls permanently lowered to no-ops.

class builtin_property_gate #(type T = int);
  semaphore token;
  mailbox box;
  process worker;
  bit passed;

  task wait_one;
    token.get(1);
    passed = 1;
  endtask

  task release_one;
    token.put(1);
  endtask

  task mailbox_put(T value);
    box.put(value);
  endtask

  function int mailbox_count;
    return box.num();
  endfunction

  function int worker_status;
    return worker.status();
  endfunction
endclass

class builtin_property_factory;
  static function builtin_property_gate#(int) make;
    builtin_property_gate#(int) tmp = new;
    return tmp;
  endfunction
endclass

module sv_param_class_builtin_property_type;
  builtin_property_gate#(int) gate;

  initial begin
    gate = builtin_property_factory::make();
    gate.token = new(0);
    gate.box = new;
    gate.worker = process::self();
    gate.passed = 0;

    fork
      gate.wait_one();
    join_none
    #1;
    if (gate.passed) begin
      $display("FAILED semaphore get did not block");
      $finish;
    end

    gate.release_one();
    #1;
    if (!gate.passed) begin
      $display("FAILED semaphore put did not release");
      $finish;
    end

    gate.mailbox_put(37);
    if (gate.mailbox_count() != 1) begin
      $display("FAILED mailbox put: count=%0d", gate.mailbox_count());
      $finish;
    end

    if (gate.worker_status() != process::RUNNING) begin
      $display("FAILED process status: %0d", gate.worker_status());
      $finish;
    end

    $display("PASSED");
  end
endmodule
