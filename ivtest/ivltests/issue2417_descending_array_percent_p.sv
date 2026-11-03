module issue2417_descending_array_percent_p;
  int descending[2:0];
  int ascending[0:2];
  string rendered;

  initial begin
    descending = '{1, 2, 3};
    ascending = '{4, 5, 6};
    rendered = $sformatf("%p", descending);
    if (rendered != "'{1, 2, 3}" || descending[2] != 1) begin
      $display("FAIL descending=%s fd[2]=%0d", rendered, descending[2]);
      $finish;
    end
    rendered = $sformatf("%p", ascending);
    if (rendered != "'{4, 5, 6}") begin
      $display("FAIL ascending=%s", rendered);
      $finish;
    end
    $display("PASS %s %s", $sformatf("%p", descending), rendered);
  end
endmodule
