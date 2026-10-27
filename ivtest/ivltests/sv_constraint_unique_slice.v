class unique_slice_item;
  rand byte a[5];
  rand byte b;
  rand byte excluded;
  constraint u { unique {b, a[2:3], excluded}; }
  constraint exclusion { excluded == 5; }
endclass

module main;
  unique_slice_item item;
  int errors;
  initial begin
    item = new;
    errors = 0;
    repeat (50) begin
      if (!item.randomize()) begin
        $display("FAIL: randomize failed");
        errors++;
      end else if (item.excluded != 5 || item.b == 5
                   || item.a[2] == 5 || item.a[3] == 5
                   || item.b == item.a[2] || item.b == item.a[3]
                   || item.b == item.excluded
                   || item.a[2] == item.a[3]
                   || item.a[2] == item.excluded
                   || item.a[3] == item.excluded) begin
        $display("FAIL: unique slice values b=%0d a2=%0d a3=%0d e=%0d",
                 item.b, item.a[2], item.a[3], item.excluded);
        errors++;
      end
    end
    if (errors) $fatal(1, "unique slice failed %0d checks", errors);
    $display("PASS: unique slice members");
    $finish;
  end
endmodule
