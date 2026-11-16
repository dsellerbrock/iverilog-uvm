// IEEE 1800-2023 18.17.7: a value-returning production that appears more
// than once in a rule is an implicit array indexed from 1, its elements
// assigned in syntactic order of appearance; once, it is a scalar.
module issue2987_randsequence_value_array;
  int first, second, a1, a2, a3, b, c1, c2, j1, j2, single;
  initial begin
    randsequence (main)
      main : value value { first = value[1]; second = value[2]; }
             nums pair joined solo;
      int value : { return 42; };
      nums : num(5) num(7) num(9) other
             { a1 = num[1]; a2 = num[2]; a3 = num[3]; b = other; };
      int num(int k) : { return k * 10; };
      int other : { return 3; };
      // Syntactic order counts both arms: num(2) is num[2].
      pair : num(1) if (1) num(2) else num(3) { c1 = num[1]; c2 = num[2]; };
      // Each rand join lane keeps its own instances.
      joined : rand join lane_a lane_b;
      lane_a : num(4) num(6) { j1 = num[1] + num[2]; };
      lane_b : num(8) { j2 = num; };
      solo : other { single = other; };
    endsequence
    $display("value=%0d,%0d num=%0d,%0d,%0d other=%0d pair=%0d,%0d join=%0d,%0d single=%0d",
             first, second, a1, a2, a3, b, c1, c2, j1, j2, single);
    if (first == 42 && second == 42 && a1 == 50 && a2 == 70 && a3 == 90
        && b == 3 && c1 == 10 && c2 == 20 && j1 == 100 && j2 == 80
        && single == 3)
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
