module main;
  logic [2:0] a = 1;
  int z;
  int loop_hits;
  int values[2];

  initial begin
    label_if: if (a == 1) z = 1; else z = 2;
    if (z != 1) $fatal(1, "if label: z=%0d", z);

    label_unique_if: unique if (a == 1) z = 2; else if (a == 2) z = 3;
    if (z != 2) $fatal(1, "unique if label: z=%0d", z);

    label_priority_if: priority if (a == 1) z = 3; else z = 4;
    if (z != 3) $fatal(1, "priority if label: z=%0d", z);

    label_case: unique case (a)
      1: z = 4;
      2: z = 5;
    endcase
    if (z != 4) $fatal(1, "case label: z=%0d", z);

    label_assign: z = 5;
    if (z != 5) $fatal(1, "assignment label: z=%0d", z);

    label_disable: if (a == 1) begin
      disable label_disable;
      z = 99;
    end
    if (z != 5) $fatal(1, "disable label: z=%0d", z);

    label_for: for (int i = 0; i < 3; i++) begin
      loop_hits++;
      if (i == 1) disable label_for;
    end
    if (loop_hits != 2) $fatal(1, "for label: loop_hits=%0d", loop_hits);

    loop_hits = 0;
    label_foreach: foreach (values[i]) begin
      loop_hits++;
      if (i == 0) disable label_foreach;
    end
    if (loop_hits != 1) $fatal(1, "foreach label: loop_hits=%0d", loop_hits);

    $display("PASSED");
  end
endmodule
