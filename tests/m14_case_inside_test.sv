// M14: `case (x) inside` (IEEE 1800-2017 12.5.4) real membership matching.
// Previously range items collapsed to their lower bound (silent
// miscompile: interior range values never matched). Now lowered to the
// `inside` operator, so ranges, comma-lists, singles, and array
// membership all match correctly.
module m14_case_inside_test_top;
  int q[$] = '{10, 20};
  int errors = 0;
  task ck(string w, int g, int e);
    if (g!==e) begin $display("FAIL %s got=%0d exp=%0d", w, g, e); errors++; end
  endtask
  function int classify(int k);
    int r = -1;
    case (k) inside
      0, 7:    r = 100;   // comma list
      [1:3]:   r = 1;     // range
      [4:6]:   r = 2;     // range
      q:       r = 50;    // array membership
      9:       r = 9;     // single
      default: r = -1;
    endcase
    return r;
  endfunction
  initial begin
    ck("k=0", classify(0), 100);
    ck("k=1", classify(1), 1);
    ck("k=2", classify(2), 1);   // interior range value (was the bug)
    ck("k=3", classify(3), 1);
    ck("k=4", classify(4), 2);
    ck("k=5", classify(5), 2);   // interior range value
    ck("k=6", classify(6), 2);
    ck("k=7", classify(7), 100);
    ck("k=8", classify(8), -1);
    ck("k=9", classify(9), 9);
    ck("k=10 (q member)", classify(10), 50);
    ck("k=11", classify(11), -1);
    if (errors==0) $display("PASS: m14 case inside");
    else $display("FAIL: m14 case inside (%0d errors)", errors);
    $finish(0);
  end
endmodule
