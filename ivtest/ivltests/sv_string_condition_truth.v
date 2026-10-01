// IEEE 1800-2017/2023 11.4.7 and 12.4: a nonempty string with a zero low
// bit is true when used as a condition. Empty strings are false.
module test;
  class item;
    int id;
  endclass

  string s, a, b, chosen;
  item yes_item, no_item, got;
  bit choose;
  int count, value, failures;
  real real_value;

  initial begin
    s = "AB"; // 16'h4142 has a zero low bit.
    if (s) count++; else failures++;
    if (count != 1 || !s) failures++;
    s = "";
    if (s) failures++;

    s = "AB";
    count = 0;
    while (s) begin count++; s = ""; end
    if (count != 1) failures++;
    s = "AB";
    count = 0;
    for (; s;) begin count++; s = ""; end
    if (count != 1) failures++;
    s = "AB";
    count = 0;
    do begin count++; if (count == 2) s = ""; end while (s);
    if (count != 2) failures++;

    s = "AB";
    value = s ? 7 : 9;
    chosen = s ? "yes" : "no";
    real_value = s ? 1.5 : 2.5;
    yes_item = new;
    no_item = new;
    yes_item.id = 1;
    no_item.id = 2;
    got = s ? yes_item : no_item;
    if (value != 7 || chosen != "yes" || real_value != 1.5 || got.id != 1)
      failures++;

    a = "AB";
    b = "";
    choose = 1;
    if (!(choose ? a : b)) failures++;
    choose = 0;
    if (choose ? a : b) failures++;
    if (failures) $fatal(1, "string conditions: %0d failures", failures);
    $display("PASSED");
  end
endmodule
