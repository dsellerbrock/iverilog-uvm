// A parameterized registry specialization may be cached by a typedef and
// first require full body elaboration from a caller's fork branch. The
// separately declared subroutine bodies are not lexically inside that fork.
// Their return statements must remain legal, while task_return_fail2 pins the
// actual return-inside-fork error.
class registry #(type T = int);
  static function int function_value();
    return 41;
  endfunction

  static task task_value(output int value);
    value = 1;
    return;
  endtask
endclass

class leaf #(type T = int);
  typedef registry#(T) type_id;
endclass

module test;
  int function_result;
  int task_result;

  initial begin
    fork
      begin
        function_result = leaf#()::type_id::function_value();
        registry#(int)::task_value(task_result);
      end
    join

    if (function_result != 41 || task_result != 1) begin
      $display("FAILED function=%0d task=%0d", function_result, task_result);
      $finish(1);
    end
    $display("PASSED");
  end
endmodule
