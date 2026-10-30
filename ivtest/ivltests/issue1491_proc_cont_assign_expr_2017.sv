module issue1491_proc_cont_assign_expr;
  logic source, sink;
  initial begin
    assign sink = (source = 1'b1);
  end
endmodule
