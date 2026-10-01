// == != === !== on unpacked structures, and on fixed unpacked arrays held in a
// struct member or class property, compare element by element (IEEE
// 1800-2017/2023 11.4.5, 7.2.1, 7.6). A struct comparison read the object
// handle as a vector and crashed vvp (SIGBUS); an array member of a struct
// compared equal whenever both operands existed.
typedef struct { int x; byte y; } flat_t;
typedef struct { int x; string s; real r; } mixed_t;
typedef struct { int x; } inner_t;
typedef struct { inner_t i; int z; } outer_t;
typedef struct { int x; int a[2]; } with_array_t;
typedef struct { int a[2][2]; } grid_t;
typedef struct { inner_t e[2]; } elems_t;
typedef struct { int x; int q[$]; } with_queue_t;

class holder;
  int arr[3] = '{1, 2, 3};
  with_array_t s;
endclass

module main;
  int errors;
  flat_t f1, f2, f3;
  mixed_t m1, m2, m3;
  outer_t o1, o2, o3;
  with_array_t w1, w2, w3;
  grid_t g1, g2, g3;
  elems_t e1, e2, e3;
  with_queue_t q1, q2, q3;
  holder h1, h2;

  task automatic expect_bit(string what, bit got, bit want);
    if (got !== want) begin
      $display("FAILED %s: got %0d want %0d", what, got, want);
      errors++;
    end
  endtask

  initial begin
    f1 = '{1, 2}; f2 = '{1, 2}; f3 = '{1, 3};
    expect_bit("flat ==", f1 == f2, 1);
    expect_bit("flat !=", f1 != f3, 1);
    expect_bit("flat == differs", f1 == f3, 0);
    expect_bit("flat ===", f1 === f2, 1);
    expect_bit("flat !==", f1 !== f3, 1);

    m1 = '{1, "a", 2.5}; m2 = '{1, "a", 2.5}; m3 = '{1, "a", 3.5};
    expect_bit("string/real ==", m1 == m2, 1);
    expect_bit("string/real !=", m1 != m3, 1);

    o1 = '{'{1}, 2}; o2 = '{'{1}, 2}; o3 = '{'{9}, 2};
    expect_bit("nested ==", o1 == o2, 1);
    expect_bit("nested !=", o1 != o3, 1);

    w1 = '{1, '{4, 5}}; w2 = '{1, '{4, 5}}; w3 = '{1, '{4, 6}};
    expect_bit("array member ==", w1 == w2, 1);
    expect_bit("array member != differs", w1 != w3, 1);
    expect_bit("array member alone ==", w1.a == w2.a, 1);
    expect_bit("array member alone differs", w1.a == w3.a, 0);
    expect_bit("array member alone !=", w1.a != w3.a, 1);

    g1.a = '{'{1, 2}, '{3, 4}}; g2.a = '{'{1, 2}, '{3, 4}}; g3.a = '{'{1, 2}, '{3, 5}};
    expect_bit("2-D array member ==", g1 == g2, 1);
    expect_bit("2-D array member !=", g1 != g3, 1);

    e1 = '{'{'{1}, '{2}}}; e2 = '{'{'{1}, '{2}}}; e3 = '{'{'{1}, '{3}}};
    expect_bit("array of structs ==", e1 == e2, 1);
    expect_bit("array of structs !=", e1 != e3, 1);

    q1.x = 1; q1.q = '{4, 5};
    q2 = q1; q3 = q1; q3.q[1] = 7;
    expect_bit("queue member ==", q1 == q2, 1);
    expect_bit("queue member !=", q1 != q3, 1);

    h1 = new; h2 = new;
    expect_bit("class array property == before", h1.arr == h2.arr, 1);
    expect_bit("class struct property == before", h1.s == h2.s, 1);
    h2.arr[2] = 9;
    h2.s.a[1] = 5;
    expect_bit("class array property differs", h1.arr == h2.arr, 0);
    expect_bit("class array property !=", h1.arr != h2.arr, 1);
    expect_bit("class struct property differs", h1.s == h2.s, 0);
    expect_bit("class struct property !=", h1.s != h2.s, 1);

    if (errors == 0) $display("PASSED");
  end
endmodule
