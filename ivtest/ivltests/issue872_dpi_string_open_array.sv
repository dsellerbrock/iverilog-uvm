// IEEE 1800-2017/2023 35.5.6.1 / Annex H.7.4: an imported subroutine may take
// an open (or fixed) unpacked array of string; each element is a const char*.
module issue872_dpi_string_open_array;
  import "DPI-C" function int c_str_total(input string a[]);
  import "DPI-C" function int c_str_size(input string a[]);
  import "DPI-C" function void c_str_fill(output string a[]);
  import "DPI-C" function void c_str_swap_ends(inout string a[]);
  import "DPI-C" function int c_str_fixed_total(input string a[3]);
  string d[];
  string q[$];
  string f[3];
  bit ok = 1;

  task check(bit c, string what);
    if (!c) begin $display("FAILED: %s", what); ok = 0; end
  endtask

  initial begin
    d = '{"a", "bb", "cccc"};
    check(c_str_total(d) == 7, "input elements");
    check(c_str_size(d) == 301, "svSize/svDimensions");
    q = {"xyz", ""};
    check(c_str_total(q) == 3, "queue actual");
    d = new[3];
    c_str_fill(d);
    check(d[0] == "alpha" && d[1] == "beta" && d[2] == "gamma", "output elements");
    d = '{"one", "two", "three"};
    c_str_swap_ends(d);
    check(d[0] == "three" && d[1] == "two" && d[2] == "one", "inout elements");
    f = '{"a", "bc", "def"};
    check(c_str_fixed_total(f) == 321, "fixed-size string array");
    if (ok) $display("ISSUE872_PASS");
    $display("PASSED");
  end
endmodule
