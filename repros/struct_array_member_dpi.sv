module top;
  import "DPI-C" function int c_take_open (input int  a[], input int want_size, input int base);
  import "DPI-C" function int c_take_byte (input byte a[], input int want_size, input int base);
  import "DPI-C" function int c_take_short(input shortint a[], input int want_size, input int base);

  typedef struct { int arr[4]; } S;
  S s;
  int  plain[4];
  int  dyn[];
  byte bytes[3];
  shortint shorts[3];
  int r;
  int fails = 0;

  task chk(string what, int got);
    if (got != 0) begin
      fails++;
      $display("FAILED -- %s: mask=%0d (1=size 2=low 4=high 8=null 16=value)", what, got);
    end
  endtask

  initial begin
    for (int i = 0; i < 4; i++) begin plain[i] = 100 + i; s.arr[i] = 200 + i; end
    dyn = new[4]; for (int i = 0; i < 4; i++) dyn[i] = 300 + i;
    for (int i = 0; i < 3; i++) begin bytes[i] = 8'(10 + i); shorts[i] = 16'(20 + i); end

    chk("a plain fixed array",                 c_take_open(plain, 4, 100));
    chk("a dynamic array",                     c_take_open(dyn,   4, 300));
    chk("a fixed array through a member select", c_take_open(s.arr, 4, 200));
    chk("a byte array",                        c_take_byte(bytes, 3, 10));
    chk("a shortint array",                    c_take_short(shorts, 3, 20));

    if (fails == 0) $display("PASSED");
    $finish(0);
  end
endmodule
