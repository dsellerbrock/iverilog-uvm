module p20_16_q3;
  integer st, v, job, inf, full;
  initial begin
    $q_initialize(1, 1, 2, st);           $display("I %0d", st);
    $q_add(1, 10, 100, st);               $display("A1 %0d", st);
    $q_add(1, 20, 200, st);               $display("A2 %0d", st);
    $q_add(1, 30, 300, st);               $display("A3 %0d", st);
    full = $q_full(1, st);                $display("F %0d %0d", full, st);
    $q_exam(1, 1, v, st);                 $display("E %0d %0d", v, st);
    $q_remove(1, job, inf, st);           $display("R1 %0d %0d %0d", job, inf, st);
    $q_remove(1, job, inf, st);           $display("R2 %0d %0d", job, st);
    $q_remove(1, job, inf, st);           $display("R3 %0d", st);
    $q_add(9, 1, 1, st);                  $display("U %0d", st);
    $q_initialize(1, 1, 2, st);           $display("D %0d", st);
    $q_initialize(2, 7, 2, st);           $display("T %0d", st);
    $q_initialize(3, 1, 0, st);           $display("L %0d", st);
    $q_initialize(4, 1, 5, st);
    $q_add(4, 1, 1, st);
    $q_add(4, 2, 2, st);
    $q_add(4, 3, 3, st);
    $q_remove(4, job, inf, st);
    $q_exam(4, 3, v, st);
    $display("M %0d %0d", v, st);
  end
endmodule
