module top;
  task automatic reported;
    logic signed [31:0] i;
    int trips;

    i = 0;
    trips = 0;
    $issue3872_check(0, i);
    while (i < 3) begin
      if (trips >= 3) $fatal(1, "too many loop iterations");
      i = i + 1;
      trips = trips + 1;
    end
    if (i !== 3 || trips != 3) $fatal(1, "wrong loop result");
    $issue3872_check(1, i);
    i = 'x;
    $issue3872_check(2, i);

    begin : named_block
      logic signed [31:0] j;
      j = 0;
      $issue3872_check(3, j);
      while (j < 2) begin
        if (j >= 2) $fatal(1, "too many named-block loop iterations");
        j = j + 1;
      end
      if (j !== 2) $fatal(1, "wrong named-block loop result");
      $issue3872_check(4, j);
    end

    trips = 0;
    while ($issue3872_predicate() > 0) begin
      trips = trips + 1;
      if (trips > 2) $fatal(1, "too many predicate loop iterations");
    end
    if (trips != 2) $fatal(1, "wrong predicate loop result");
    $issue3872_finish;
  endtask

  initial reported();
endmodule
