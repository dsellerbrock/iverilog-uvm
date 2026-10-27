package issue1235_let_pkg;
  let plus_package(x) = x + 1;
endpackage

module issue1235_let_nested_scopes;
  import issue1235_let_pkg::*;
  logic [7:0] block_result;
  logic [7:0] task_result;
  logic [7:0] function_result;
  logic [7:0] generated_result;

  if (1) begin : generated
    let plus_generated(x) = x + 1;
    assign generated_result = plus_generated(4);
  end

  task automatic run_task;
    let plus_task(x) = x + 1;
    task_result = plus_task(5);
  endtask

  function automatic [7:0] run_function(input [7:0] value);
    let plus_function(x) = x + 1;
    run_function = plus_function(value);
  endfunction

  initial begin : block_scope
    let plus_block(x) = x + 1;
    block_result = plus_block(6);
  end

  initial begin
    run_task();
    function_result = run_function(7);
    #1;
    if (block_result !== 7 || task_result !== 6 || function_result !== 8 ||
        generated_result !== 5 || plus_package(8) !== 9)
      $fatal(1, "let scope values block=%0d task=%0d function=%0d generate=%0d package=%0d",
             block_result, task_result, function_result, generated_result,
             plus_package(8));
    $display("PASSED");
    $finish;
  end
endmodule
