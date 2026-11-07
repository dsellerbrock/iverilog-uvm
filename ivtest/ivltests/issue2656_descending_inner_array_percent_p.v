module issue2656_descending_inner_array_percent_p;
  int m[0:1][2:0];
  string rendered;

  initial begin
    foreach (m[q, r]) m[q][r] = q*10 + r;
    rendered = $sformatf("%p", m);
    if (rendered != "'{2, 1, 0, 12, 11, 10}") begin
      $display("FAIL multidimensional descending %s", rendered);
      $finish;
    end
    $display("PASS %s", rendered);
  end
endmodule
