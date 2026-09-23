class task_codegen_error_holder;
  logic [7:0] value;
endclass

module sv_task_codegen_error_status_fail;
  task_codegen_error_holder obj;
  logic [7:0] plain;

  task automatic unsupported_concat_nba;
    {obj.value, plain} <= 16'h1234;
  endtask

  initial begin
    obj = new;
    unsupported_concat_nba();
  end
endmodule
