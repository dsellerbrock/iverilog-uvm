// IEEE 1800-2017 7.12.4 iterator index querying: `item.index` (and
// the call forms index() / index(1)) inside an array-method with
// expression reads the element index of the enclosing iteration.
// Also pins the test_width fix this required: array reduction methods
// used as OPERANDS previously computed context width 0 (operands were
// padded to zero bits and the whole expression evaluated to 0).
class g10ii_holder;
  int q[$];
endclass

module g10_iter_index_test;
  int errors = 0;
  int arr[];
  int q[$];
  int iq[$];
  int sq[$];
  int inner[$];
  int r;
  g10ii_holder h;

  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %s: got %0d expect %0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    // LRM 7.12.4 literal example: items equal to their position
    arr = new[5];
    arr[0] = 0; arr[1] = 9; arr[2] = 2; arr[3] = 9; arr[4] = 4;
    q = arr.find with ( item == item.index );
    check("lrm find size", q.size(), 3);
    check("lrm find [0]", q[0], 0);
    check("lrm find [2]", q[2], 4);

    // locator, reduction, min/max, sort with index
    q = arr.find_index with ( item.index >= 3 );
    check("fidx size", q.size(), 2);
    check("fidx [0]", q[0], 3);
    r = arr.sum with ( item.index );
    check("sum of indices", r, 10);
    r = arr.sum with ( item * item.index );
    check("weighted sum", r, 56);
    iq.push_back(5); iq.push_back(0); iq.push_back(7);
    q = iq.max() with (item.index);
    check("max by index", q[0], 7);
    sq = '{10, 20, 30};
    sq.sort() with (-item.index);
    check("sort by -index", sq[0], 30);

    // call forms; default dimension 1
    r = iq.sum with (item.index());
    check("index()", r, 3);
    r = iq.sum with (item.index(1));
    check("index(1)", r, 3);

    // custom iterator name
    q = iq.find_index(x) with (x.index == 1);
    check("custom iter", q[0], 1);

    // class-property receiver
    h = new;
    h.q.push_back(4); h.q.push_back(4);
    r = h.q.sum with (item * item.index);
    check("property recv", r, 4);

    // nested with expressions: inner index, and outer index reached
    // from inside the inner with
    q.delete();
    q.push_back(10); q.push_back(20);
    inner.push_back(100); inner.push_back(200); inner.push_back(300);
    r = q.sum with (item + inner.sum with (item.index));
    check("nested inner index", r, 36);
    begin
      automatic int zq[$] = '{0, 0, 0};
      r = q.sum(o) with (zq.sum(x) with (x.index + o.index));
      check("outer index in inner", r, 9);
    end

    // reductions as operands (the width-0 context defect)
    q.delete();
    q.push_back(3); q.push_back(4);
    r = q.sum() + 1;
    check("plain op ctx", r, 8);
    r = q.sum() with (item * 2) + 5;
    check("with op ctx", r, 19);
    r = 2 * q.sum() with (item) - q.sum();
    check("mixed op ctx", r, 7);
    begin
      automatic byte b2[] = new[2];
      b2[0] = 8'h80; b2[1] = 1;
      r = b2.sum() + 0;
      check("signed elem width op ctx", r, -127);
    end

    if (errors == 0) $display("PASS");
    else $display("%0d checks failed", errors);
    $finish;
  end
endmodule
