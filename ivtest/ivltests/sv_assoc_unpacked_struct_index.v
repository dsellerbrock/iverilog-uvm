// IEEE 1800-2017/2023 7.8.5: an unpacked struct with equality defined is a
// legal associative-array index type.
module main;
  typedef struct { byte B; int I; } key_t;
  int values[key_t];
  key_t first, second, absent;

  initial begin
    first = '{1, 10};
    second = '{2, 20};
    absent = '{1, 11};
    values[first] = 5;
    values[second] = 6;

    if (values.size() != 2 || values[first] != 5 || values.exists(absent))
      $fatal(1, "struct associative index mismatch: size=%0d value=%0d exists=%0d",
             values.size(), values[first], values.exists(absent));
    $display("A4 %0d %0d %0d", values.size(), values[first], values.exists(absent));
    $display("PASSED");
  end
endmodule
