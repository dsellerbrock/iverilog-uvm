module p07_12_methods;
  int a[] = '{4, 7, 2, 7, 9}; int q[$]; int s[];
  byte b[] = '{1, 2, 3, 4}; logic [7:0] m[2][2] = '{'{5, 10}, '{15, 20}};
  bit [7:0] w[] = '{200, 100}; int y;
  function automatic string qs(int x[$]); string t = ""; foreach (x[i]) t = {t, $sformatf("%0d ", x[i])}; return t; endfunction
  initial begin
    q = a.find with (item > 5);              $display("L1 %s", qs(q));
    q = a.find_index with (item == 7);       $display("L2 %s", qs(q));
    q = a.find_first with (item > 5);        $display("L3 %s", qs(q));
    q = a.find_first_index with (item > 5);  $display("L3I %s", qs(q));
    q = a.find_last with (item < 5);         $display("L4 %s", qs(q));
    q = a.find_last_index with (item < 5);   $display("L4I %s", qs(q));
    q = a.min; $display("L5 %s", qs(q)); q = a.max; $display("L5X %s", qs(q));
    q = a.unique; $display("L6 %0d %0d", q.size(), q.sum());
    q = a.find with (item > 100);            $display("L8 %0d", q.size());
    q = a.find with (item > item.index);     $display("I1 %s", qs(q));
    s = a; s.sort;    $display("O1 %s", qs(s));
    s = a; s.rsort;   $display("O2 %s", qs(s));
    s = a; s.reverse; $display("O3 %s", qs(s));
    s = a; s.shuffle; $display("O4 %0d %0d", s.size(), s.sum());
    s = a; s.sort with (item % 3); $display("O5 %0d %0d", s[0] % 3, s[4] % 3);
    y = b.sum; $display("R1 %0d", y); y = b.product; $display("R2 %0d", y);
    y = b.xor with (item + 4); $display("R3 %0d", y);
    y = m.sum with (item.sum with (item)); $display("R4 %0d", y);
    y = w.sum; $display("R5 %0d", y); y = w.sum with (int'(item)); $display("R6 %0d", y);
  end
endmodule
