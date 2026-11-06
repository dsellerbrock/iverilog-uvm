module issue2543_struct_array_percent_p;
  typedef struct { int a; int arr[2]; } s_t;
  s_t s; s_t q[$];
  initial begin
    s.a = 1; s.arr = '{2, 3}; q.push_back(s);
    $display("%p", s);
    $display("%p", q);
  end
endmodule
