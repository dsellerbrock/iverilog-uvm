// IEEE 1800-2017 21.2.1.3: the %p (assignment-pattern) format applied to
// aggregates. Previously %p asked every element for its string value, which
// rendered integral elements as raw ASCII bytes (the value 99 came out as
// 'c') and hit an unimplemented get_word(string) path for queue and dynamic
// array elements, so integral aggregates printed empty or garbage:
//   queue  -> '{, }        (should be '{10, 20})
//   assoc  -> '{c, *}      (should be '{3:99, 7:42})
//   dynarr -> '{, , }      (should be '{1, 2, 3})
//   scalar -> <byte>       (should be 195)
//
// This test pins the corrected output for the common shapes via $sformatf
// so it needs no gold file (the harness passes a `normal` test on a bare
// PASSED line).

module sv_display_p_aggregates;

  int    q[$];
  int    dyn[];
  int    fix[4];
  int    iaa[int];
  string saa[string];
  string sq[$];
  real   rq[$];
  logic [7:0] v;
  int    eq[$];

  int errors = 0;

  task automatic chk(string what, string got, string exp);
    if (got != exp) begin
      $display("FAIL %0s: got %0s exp %0s", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    q.push_back(10); q.push_back(20);
    dyn = new[3]; dyn[0]=1; dyn[1]=2; dyn[2]=3;
    fix[0]=5; fix[1]=6; fix[2]=7; fix[3]=8;
    iaa[3]=99; iaa[7]=42;
    saa["red"]="r"; saa["green"]="g";
    sq.push_back("foo"); sq.push_back("bar");
    rq.push_back(1.5); rq.push_back(2.25);
    v = 8'hC3;

    chk("queue",   $sformatf("%p", q),   "'{10, 20}");
    chk("dynarr",  $sformatf("%p", dyn), "'{1, 2, 3}");
    chk("fixed",   $sformatf("%p", fix), "'{5, 6, 7, 8}");
    chk("int-aa",  $sformatf("%p", iaa), "'{3:99, 7:42}");
    chk("str-aa",  $sformatf("%p", saa), "'{green:\"g\", red:\"r\"}");
    chk("str-q",   $sformatf("%p", sq),  "'{\"foo\", \"bar\"}");
    chk("real-q",  $sformatf("%p", rq),  "'{1.5, 2.25}");
    chk("scalar",  $sformatf("%p", v),   "195");
    chk("empty-q", $sformatf("%p", eq),  "'{}");

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
