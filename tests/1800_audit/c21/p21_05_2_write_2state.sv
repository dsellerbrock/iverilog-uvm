module p21_05_2_write_2state;
  int values[0:1];
  typedef enum bit [3:0] {E0 = 4'hA, E1 = 4'h5} enum_t;
  enum_t enums[0:1];

  initial begin
    values[0] = 5;
    values[1] = 10;
    enums[0] = E0;
    enums[1] = E1;
    $writememb("int.mem", values);
    $writememh("enum.hex", enums);
    $display("PASS wrote 2-state int and enum arrays");
  end
endmodule
