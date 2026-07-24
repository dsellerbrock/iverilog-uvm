// Queue-of-queues and queue-literal semantics:
// - queue literals as method arguments (push_back/insert) build real
//   queue values (were silently null: outer grew, inner was empty and
//   unusable);
// - whole-queue nested literal assignment distinguishes ELEMENTS from
//   same-shape COLLECTIONS (10.10: {q_a, q_b} concatenates; {{1},{2}}
//   into q[$][$] appends elements);
// - flat splices {q1, 5, q2} concatenate for vec4/string/real element
//   queues, including class-property targets;
// - value semantics: a stored element does not alias its source.
module main;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  int qq[$][$];
  int q1[$], q2[$], q[$];
  string s1[$], s[$];
  real r1[$], r[$];
  class C;
    int q[$];
    int qq[$][$];
  endclass

  initial begin
    automatic C c = new;

    // literal push_back
    qq.push_back({1,2});
    qq.push_back({3});
    check("literal push", qq.size() == 2 && qq[0].size() == 2
          && qq[0][1] == 2 && qq[1][0] == 3);

    // nested mutation through the outer element
    qq[1].push_back(7);
    check("nested push", qq[1].size() == 2 && qq[1][1] == 7);
    check("nested pop", qq[1].pop_front() == 3 && qq[1].size() == 1);

    // empty literal then growth
    qq.push_back({});
    qq[2].push_back(42);
    check("empty literal grow", qq[2].size() == 1 && qq[2][0] == 42);

    // insert with literal
    qq.insert(1, {55});
    check("insert literal", qq.size() == 4 && qq[1][0] == 55 && qq[2][0] == 7);

    // value semantics
    q1 = {1,2};
    qq = {};
    qq.push_back(q1);
    q1.push_back(99);
    check("value copy", qq[0].size() == 2 && q1.size() == 3);

    // whole nested literal assignment (elements, not splices)
    qq = {{1},{2,3}};
    check("nested whole literal", qq.size() == 2 && qq[0].size() == 1
          && qq[1].size() == 2 && qq[1][1] == 3);

    // nested splice: {qq, qq2} concatenates same-shape collections
    begin
      automatic int qq2[$][$];
      automatic int qqr[$][$];
      qq2 = {{9}};
      qqr = {qq, qq2};
      check("nested splice", qqr.size() == 3 && qqr[2][0] == 9);
      qqr = {{8}, qq};
      check("mixed elem+splice", qqr.size() == 3 && qqr[0][0] == 8
            && qqr[1][0] == 1 && qqr[2][1] == 3);
    end

    // flat splices
    q1 = {1,2}; q2 = {3};
    q = {q1, 5, q2};
    check("flat splice", q.size() == 4 && q[0] == 1 && q[1] == 2
          && q[2] == 5 && q[3] == 3);
    s1 = {"a","b"};
    s = {s1, "c"};
    check("string splice", s.size() == 3 && s[2] == "c");
    r1 = {1.5};
    r = {r1, 2.5};
    check("real splice", r.size() == 2 && r[1] == 2.5);

    // class-property targets
    c.q = {q1, 7};
    check("prop splice", c.q.size() == 3 && c.q[0] == 1 && c.q[2] == 7);
    c.qq = {{4},{5,6}};
    check("prop qq literal", c.qq.size() == 2 && c.qq[0][0] == 4
          && c.qq[1][1] == 6);
    c.qq.push_back({8});
    c.qq[2].push_back(9);
    check("prop qq nested", c.qq[2].size() == 2 && c.qq[2][1] == 9);

    if (!failed) $display("PASSED");
  end
endmodule
