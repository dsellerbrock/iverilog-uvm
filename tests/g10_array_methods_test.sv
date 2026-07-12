// G10: array manipulation methods (IEEE 1800-2017 7.12) — reduction
// methods (7.12.3: sum, product, and, or, xor) and the min()/max()
// locators (7.12.1) over queues, dynamic arrays and fixed-size
// unpacked arrays, in call, call-with, paren-less and paren-less-with
// forms, including the keyword-named methods (and/or/xor) and
// per-call iterator binding ("The scope for the iterator_argument is
// the with expression").
// Class-property receivers (the dominant UVM shape): the loop cannot
// index a property directly, so the code generator evaluates the
// receiver object once into a hidden container net.
class g10_stats;
  int q[$];
  byte d[];
endclass

class g10_cfg;
  g10_stats st;
  function new; st = new; endfunction
endclass

class g10_scoreboard;
  int q[$];
  function int get_sum(); return q.sum(); endfunction
  function int get_sum_parenless(); return q.sum; endfunction
  function int get_sumw(); return q.sum() with (item * 2); endfunction
  function int get_max();
    int mq[$];
    mq = q.max();
    return mq[0];
  endfunction
  function int get_fidx_count();
    int idxq[$];
    idxq = q.find_index() with (item > 1);
    return idxq.size();
  endfunction
endclass

module g10_array_methods_test;
  int errors = 0;

  byte b[];
  int q[$];
  int d[];
  int f[5];
  logic [7:0] u[$];
  int d2[];       // stays empty
  int qe[$];      // stays empty
  int mq[$];
  logic [7:0] uq[$];
  int idxq[$];
  bit bit_arr [10];
  int y;

  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %s: got %0d expect %0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    // LRM 7.12.3 literal examples: byte b[] = { 1, 2, 3, 4 };
    b = new[4]; b[0] = 1; b[1] = 2; b[2] = 3; b[3] = 4;
    y = b.sum;                    check("b.sum", y, 10);
    y = b.product;                check("b.product", y, 24);
    y = b.xor with (item + 4);    check("b.xor with", y, 12); // 5^6^7^8

    // queue reductions, call and with forms
    q.push_back(3); q.push_back(1); q.push_back(2);
    y = q.sum();                  check("q.sum()", y, 6);
    y = q.sum() with (item * 2);  check("q.sum() with", y, 12);
    y = q.sum(x) with (x * 3);    check("q.sum(x) with", y, 18);

    // keyword-named methods: call, call-with, paren-less-with
    q.delete(); q.push_back(12); q.push_back(10);
    y = q.and();                  check("q.and()", y, 8);
    y = q.or();                   check("q.or()", y, 14);
    y = q.xor();                  check("q.xor()", y, 6);
    y = q.and() with (item | 1);  check("q.and() with", y, 9);
    y = q.xor with (item);        check("q.xor with", y, 6);

    // dynamic array reductions
    d = new[3]; d[0] = 3; d[1] = 1; d[2] = 2;
    y = d.sum();                  check("d.sum()", y, 6);
    y = d.product();              check("d.product()", y, 6);
    y = d.sum() with (item * 2);  check("d.sum() with", y, 12);

    // fixed-size array reductions and locators
    f[0] = 3; f[1] = 1; f[2] = 2; f[3] = 5; f[4] = 4;
    y = f.sum();                  check("f.sum()", y, 15);
    y = f.sum;                    check("f.sum", y, 15);
    mq = f.max();                 check("f.max()", mq[0], 5);
    mq = f.min();                 check("f.min()", mq[0], 1);
    idxq = f.find_index() with (item > 2);
    check("f.find_index size", idxq.size(), 3);
    check("f.find_index [0]", idxq[0], 0);

    // min/max: signed elements, empty arrays, with-clause remap
    q.delete(); q.push_back(-5); q.push_back(3); q.push_back(-7);
    mq = q.min();                 check("q.min signed", mq[0], -7);
    mq = q.max();                 check("q.max signed", mq[0], 3);
    y = q.sum();                  check("q.sum signed", y, -9);
    mq = q.max() with (-item);    check("q.max with -item", mq[0], -7);
    mq = d.max();                 check("d.max()", mq[0], 3);
    mq = d.min();                 check("d.min()", mq[0], 1);

    // unsigned element comparison (F0 > 0F unsigned; -16 < 15 signed)
    u.push_back(8'hF0); u.push_back(8'h0F);
    uq = u.max();                 check("u.max unsigned", uq[0], 8'hF0);

    // empty arrays: sum identity 0, product identity 1, empty queue
    y = d2.sum();                 check("empty d.sum", y, 0);
    y = qe.product();             check("empty q.product", y, 1);
    mq = qe.max();                check("empty q.max size", mq.size(), 0);

    // per-call iterator binding: bit elements after byte elements in
    // the same scope must not reuse the byte-typed hidden iterator
    // (LRM: the iterator argument is scoped to the with expression).
    bit_arr[1] = 1; bit_arr[3] = 1; bit_arr[7] = 1;
    y = bit_arr.sum with (int'(item));
    check("bit_arr.sum with cast", y, 3);

    // a user variable named `item` is shadowed by the iterator inside
    // the with expression and must survive the loop unmodified
    begin
      automatic int item = 99;
      qe.push_back(2); qe.push_back(3);
      y = qe.sum() with (item * 10);
      check("shadowed item sum", y, 50);
      check("user item preserved", item, 99);
      qe.delete();
    end

    // class-property receivers: method-internal, external, nested
    // chains, paren-less, with-clause, locators, empties
    begin
      automatic g10_scoreboard sb = new;
      automatic g10_cfg cfg = new;
      automatic int mq2[$];
      sb.q.push_back(3); sb.q.push_back(1); sb.q.push_back(2);
      check("prop q.sum()", sb.get_sum(), 6);
      check("prop q.sum parenless", sb.get_sum_parenless(), 6);
      check("prop q.sum with", sb.get_sumw(), 12);
      check("prop q.max", sb.get_max(), 3);
      check("prop find_index with", sb.get_fidx_count(), 2);
      check("ext prop sum", sb.q.sum(), 6);
      check("ext prop sum parenless", sb.q.sum, 6);

      cfg.st.q.push_back(4); cfg.st.q.push_back(5);
      cfg.st.d = new[3];
      cfg.st.d[0] = 1; cfg.st.d[1] = 2; cfg.st.d[2] = 3;
      check("nested prop q.sum", cfg.st.q.sum(), 9);
      check("nested prop d.sum with", cfg.st.d.sum() with (item * 2), 12);
      check("nested prop q.and", cfg.st.q.and(), 4);
      mq2 = cfg.st.q.max();
      check("nested prop q.max", mq2[0], 5);
      mq2 = cfg.st.q.find() with (item > 4);
      check("nested prop find size", mq2.size(), 1);
      check("nested prop find val", mq2[0], 5);
    end

    if (errors == 0) $display("PASS");
    else $display("%0d checks failed", errors);
    $finish;
  end
endmodule
