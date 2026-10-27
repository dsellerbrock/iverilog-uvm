module main;
  logic a;

  initial begin
    $display("past=%b", $past(a));
    $display("rose=%b", $rose(a));
    $display("fell=%b", $fell(a));
    $display("stable=%b", $stable(a));
    $display("changed=%b", $changed(a));
  end
endmodule
