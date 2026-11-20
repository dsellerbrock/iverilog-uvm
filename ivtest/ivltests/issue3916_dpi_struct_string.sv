// IEEE 1800-2017/2023 H.7.8 and H.8.10.1: a string member is a const char*.
module test;
  typedef struct { byte tag; string text; real value; } item_t;

  import "DPI-C" function int c_check_items(input item_t a[]);
  import "DPI-C" function int c_fill_items(output item_t a[]);
  import "DPI-C" function int c_rotate_items(inout item_t a[]);
  import "DPI-C" function int c_swap_with_fixed(inout item_t scalar,
                                                inout item_t fixed_items[2]);

  item_t a[], out_items[], scalar, fixed_items[2];

  initial begin
    a = new[3];
    a[0] = '{11, "first", 1.25};
    a[1] = '{22, "", 2.5};
    a[2] = '{33, "a longer string stored in the third element", 3.75};
    if (c_check_items(a) != 1)
      $fatal(1, "open input layout, stride or string contents");

    out_items = new[3];
    if (c_fill_items(out_items) != 1)
      $fatal(1, "open output layout");
    if (out_items[0].tag !== 41 || out_items[0].text != "written by C" || out_items[0].value != 4.5 ||
        out_items[1].tag !== 42 || out_items[1].text != ""             || out_items[1].value != 5.5 ||
        out_items[2].tag !== 43 || out_items[2].text != "last output"  || out_items[2].value != 6.5)
      $fatal(1, "open output copyback into unwritten elements");

    if (c_rotate_items(a) != 1)
      $fatal(1, "open inout layout");
    if (a[0].tag !== 11 || a[0].text != "a longer string stored in the third element" || a[0].value != 1.25 ||
        a[1].tag !== 22 || a[1].text != "first" || a[1].value != 2.5 ||
        a[2].tag !== 33 || a[2].text != ""      || a[2].value != 3.75)
      $fatal(1, "open inout pointer rotation");

    scalar = '{51, "scalar", 7.5};
    fixed_items[0] = '{52, "", 8.5};
    fixed_items[1] = '{53, "fixed", 9.5};
    if (c_swap_with_fixed(scalar, fixed_items) != 1)
      $fatal(1, "scalar or fixed array input layout");
    if (scalar.tag         !== 51 || scalar.text         != "fixed"  || scalar.value         != 7.5 ||
        fixed_items[0].tag !== 52 || fixed_items[0].text != ""       || fixed_items[0].value != 8.5 ||
        fixed_items[1].tag !== 53 || fixed_items[1].text != "scalar" || fixed_items[1].value != 9.5)
      $fatal(1, "scalar and fixed array pointer swap");

    $display("PASSED");
  end
endmodule
