class phase_t;
  typedef bit edges_t[phase_t];
  edges_t preds;
endclass

module test;
  task automatic fail(input string tag);
    $display("FAIL %s", tag);
    $finish_and_return(1);
  endtask

  task automatic check_only_a(input string tag, phase_t::edges_t edges,
                              phase_t a, phase_t b);
    phase_t k;
    int count;
    bit saw_a;
    bit saw_b;
    count = 0;
    saw_a = 1'b0;
    saw_b = 1'b0;
    foreach (edges[k]) begin
      count += 1;
      if (k == a) saw_a = 1'b1;
      if (k == b) saw_b = 1'b1;
    end
    if (count != 1 || !saw_a || saw_b) fail(tag);
  endtask

  task automatic check_only_b(input string tag, phase_t::edges_t edges,
                              phase_t a, phase_t b);
    phase_t k;
    int count;
    bit saw_a;
    bit saw_b;
    count = 0;
    saw_a = 1'b0;
    saw_b = 1'b0;
    foreach (edges[k]) begin
      count += 1;
      if (k == a) saw_a = 1'b1;
      if (k == b) saw_b = 1'b1;
    end
    if (count != 1 || !saw_b || saw_a) fail(tag);
  endtask

  initial begin
    phase_t a;
    phase_t b;
    phase_t x;
    phase_t y;

    a = new();
    b = new();
    x = new();
    y = new();
    x.preds[a] = 1'b1;
    y.preds = x.preds;
    x.preds[b] = 1'b1;
    check_only_a("mutate-source-after-copy", y.preds, a, b);

    a = new();
    b = new();
    x = new();
    y = new();
    x.preds[a] = 1'b1;
    y.preds = x.preds;
    x.preds.delete();
    x.preds[b] = 1'b1;
    check_only_a("clear-source-after-copy", y.preds, a, b);

    a = new();
    b = new();
    x = new();
    y = new();
    x.preds[a] = 1'b1;
    y.preds = x.preds;
    y.preds[b] = 1'b1;
    check_only_a("mutate-dest-after-copy", x.preds, a, b);

    $display("PASSED");
  end
endmodule
