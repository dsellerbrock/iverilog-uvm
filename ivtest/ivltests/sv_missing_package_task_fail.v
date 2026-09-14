task missing_task;
  $display("WRONG_UNIT_TASK");
endtask

function void missing_function;
  $display("WRONG_UNIT_FUNCTION");
endfunction

package existing_pkg; endpackage
package second_pkg; endpackage

module test;
  initial begin
    existing_pkg::missing_task();
    second_pkg::missing_function();
  end
endmodule
