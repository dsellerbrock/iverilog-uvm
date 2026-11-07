// IEEE 1800-2017/2023 20.6.2: $bits returns the number of data bits of a
// fixed-size type or object, including unpacked structs ("$bits(MyType)
// shall return 9").
module issue788_bits_unpacked_struct;
  typedef struct {logic valid; bit [8:1] data;} MyType;
  typedef struct {MyType a; int b[2]; logic [3:0] c;} Outer;
  typedef MyType MyArr[3];
  typedef struct packed {logic valid; bit [8:1] data;} MyPacked;

  MyType mt;
  Outer o;
  MyPacked mp;

  localparam int W = $bits(MyType);
  logic [W-1:0] flat;

  bit ok = 1;

  task automatic check(string what, int got, int want);
    if (got !== want) begin
      $display("FAILED: %s = %0d, expected %0d", what, got, want);
      ok = 0;
    end
  endtask

  initial begin
    check("$bits(MyType)", $bits(MyType), 9);
    check("$bits(mt)", $bits(mt), 9);
    check("$bits(Outer)", $bits(Outer), 77);
    check("$bits(o)", $bits(o), 77);
    check("$bits(o.a)", $bits(o.a), 9);
    check("$bits(MyArr)", $bits(MyArr), 27);
    check("$bits(MyPacked)", $bits(MyPacked), 9);
    check("$bits(mp)", $bits(mp), 9);
    check("localparam", $bits(flat), 9);
    if (ok) $display("PASSED");
  end
endmodule
