// The statement-context port-direction rule (added for non-ANSI task
// declarations that arrive after the declaration-section early exit)
// must NOT accept a direction declaration outside a task/function body.
// IEEE 1800-2017 A.2.7: tf_port_declaration belongs to task/function
// bodies only.
module stmt_input_outside_task;
  initial begin
    int x;
    input y;    // error: not a task/function body
    x = 1;
  end
endmodule
