module top;
  logic [7:0] empty_dyn[];
  logic [7:0] nonempty_dyn[];

  initial begin
    empty_dyn = new[0];
    nonempty_dyn = new[3];
    #1;
    $probe_empty_dynamic_range;
    $finish;
  end
endmodule
