// Reading an element of a container-typed struct member through a
// container element: q[0].da[i] and q[0].aa[key]. Pre-fix, the member
// index elaborated as an untyped 1-bit select, so the whole expression
// stayed object-typed and the read came back nil (displayed as null /
// zero) with a runtime type-mismatch warning. The struct itself also
// lost container members when pushed into a queue (the queue element
// store did not deep-copy struct fields).
typedef struct {
  int da[];
  int aa[string];
  string str;
} rec_t;

module main;
  rec_t q[$];
  rec_t d[];
  int fails = 0;

  initial begin
    begin
      rec_t tmp;
      tmp.da = new[2]; tmp.da[0] = 10; tmp.da[1] = 11;
      tmp.aa["k"] = 100;
      tmp.str = "hello";
      q.push_back(tmp);
      d = new[1];
      d[0] = tmp;
    end

    // struct fields survive the push (D7): container members included.
    if (q[0].da.size() != 2) begin fails++; $display("FAILED: da.size=%0d", q[0].da.size()); end

    // element reads through the queue element are typed and land.
    if (q[0].da[0] !== 10) begin fails++; $display("FAILED: q[0].da[0]=%0d", q[0].da[0]); end
    if (q[0].da[1] !== 11) begin fails++; $display("FAILED: q[0].da[1]=%0d", q[0].da[1]); end
    if (q[0].aa["k"] !== 100) begin fails++; $display("FAILED: q[0].aa[k]=%0d", q[0].aa["k"]); end
    if (q[0].str != "hello") begin fails++; $display("FAILED: q[0].str='%s'", q[0].str); end

    // same shapes through a darray element.
    if (d[0].da[1] !== 11) begin fails++; $display("FAILED: d[0].da[1]=%0d", d[0].da[1]); end
    if (d[0].aa["k"] !== 100) begin fails++; $display("FAILED: d[0].aa[k]=%0d", d[0].aa["k"]); end

    // a variable index, and use in an expression context.
    begin
      int i = 1;
      int sum;
      sum = q[0].da[0] + q[0].da[i];
      if (sum !== 21) begin fails++; $display("FAILED: sum=%0d", sum); end
    end

    // writes through the same path still land.
    q[0].da[0] = 999;
    if (q[0].da[0] !== 999) begin fails++; $display("FAILED: write-back=%0d", q[0].da[0]); end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
