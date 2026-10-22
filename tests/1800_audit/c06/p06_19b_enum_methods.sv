module p06_19b_enum_methods;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++;
    else begin fail++; $display("FAIL %s", id); end
  endtask

  typedef enum {red, green, blue, yellow} Colors;
  typedef enum {A=1, B=3, C=7, D=10} Sp;
  class K; Colors col = green; endclass
  Colors c, bad, arr[2];
  Sp s;
  K k;
  Colors q[$];
  string line;

  initial begin
    c = red;
    ck("first", c.first == red && c.first() == red);
    ck("last", c.last == yellow && c.last() == yellow);
    ck("next", c.next == green && c.next(2) == blue && c.next(0) == red);
    c = yellow;
    ck("next_wrap", c.next == red && c.next(4) == yellow && c.next(5) == red);
    c = red;
    ck("prev_wrap", c.prev == yellow && c.prev(2) == blue && c.prev(5) == yellow);
    ck("num", c.num == 4 && c.num() == 4 && s.num == 4 && $bits(c.num) == 32);
    s = A;
    ck("sparse_next", s.next == B && s.next(2) == C && s.prev == D);
    s = D;
    ck("sparse_wrap", s.next == A && s.last == D && s.first == A);
    c = green;
    ck("name", c.name == "green" && c.name() == "green" && c.name().len() == 5);
    bad = Colors'(9);
    ck("name_oob", bad.name == "");
    k = new;
    ck("class_prop", k.col.name() == "green" && k.col.next() == blue && k.col.first() == red);
    arr[1] = blue;
    ck("array_elem", arr[1].name() == "blue" && arr[1].next() == yellow);
    q.push_back(yellow);
    ck("queue_elem", q[0].name() == "yellow" && q[0].next() == red);
    s = Sp'(0);
    $display("INFO nonmember Sp'(0): next=%0d prev=%0d name='%s'", s.next, s.prev, s.name);
    bad = Colors'(9);
    $display("INFO nonmember Colors'(9): next=%0d prev=%0d", bad.next, bad.prev);
    line = "";
    c = c.first;
    forever begin
      line = {line, $sformatf("%s:%0d;", c.name, c)};
      if (c == c.last) break;
      c = c.next;
    end
    ck("loop_6_19_5_7", line == "red:0;green:1;blue:2;yellow:3;");
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
