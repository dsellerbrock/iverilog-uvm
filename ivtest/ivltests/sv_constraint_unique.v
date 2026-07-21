// IEEE 1800-2017 18.5.5: unique {} constraint — the listed variables and
// array elements take pairwise-distinct values. Previously a syntax error.
module sv_constraint_unique;
  class ArrC;
    rand int arr[5];
    constraint c { unique { arr }; foreach (arr[i]) arr[i] inside {[0:4]}; }
  endclass
  class ScalC;
    rand bit [2:0] a, b, cc;
    constraint k { unique {a, b, cc}; a < 6; b < 6; cc < 6; }
  endclass
  int errors = 0;
  initial begin
    ArrC  ac = new;
    ScalC sc = new;
    for (int t = 0; t < 25; t++) begin
      if (!ac.randomize()) begin $display("FAIL: array rand=0"); errors++; break; end
      for (int i = 0; i < 5; i++)
        for (int j = i+1; j < 5; j++)
          if (ac.arr[i] == ac.arr[j]) begin
            $display("FAIL: dup arr[%0d]==arr[%0d]", i, j); errors++;
          end
    end
    for (int t = 0; t < 25; t++) begin
      if (!sc.randomize()) begin $display("FAIL: scalar rand=0"); errors++; break; end
      if (sc.a==sc.b || sc.a==sc.cc || sc.b==sc.cc) begin
        $display("FAIL: dup scalars %0d %0d %0d", sc.a, sc.b, sc.cc); errors++;
      end
    end
    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d)", errors);
  end
endmodule
