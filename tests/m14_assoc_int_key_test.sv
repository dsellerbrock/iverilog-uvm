// M14: module-static integer-keyed associative array value storage
// (IEEE 1800-2017 7.8). Previously a module-scope `int m[int]` stored
// via %aa/store but READ via a positional darray load, silently
// returning the default (keys were correct, values lost). Class-member
// assoc arrays were unaffected. Now the integer-keyed read uses the
// assoc load.
module m14_assoc_int_key_test_top;
  int         a[int];
  logic [7:0] c[int];
  bit  [3:0]  d[int];
  int errors = 0;
  task ck(string w, int g, int e);
    if (g!==e) begin $display("FAIL %s got=%0d exp=%0d", w, g, e); errors++; end
  endtask
  initial begin
    a[5]=42; a[10]=99; a[0]=7;
    c[3]=8'hAB; d[2]=4'hC;
    ck("a[5]",  a[5],  42);
    ck("a[10]", a[10], 99);
    ck("a[0]",  a[0],  7);
    ck("c[3]",  c[3],  'hAB);
    ck("d[2]",  d[2],  'hC);
    ck("num",   a.num(), 3);
    ck("exists",a.exists(10), 1);
    begin int s=0; foreach (a[i]) s += a[i]; ck("foreach sum", s, 148); end
    if (errors==0) $display("PASS: m14 assoc int key");
    else $display("FAIL: m14 assoc int key (%0d errors)", errors);
    $finish(0);
  end
endmodule
