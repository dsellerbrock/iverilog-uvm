// Reading an element of an UNPACKED ARRAY member of a struct
// (IEEE 1800-2017 7.2.1: a struct member is accessed by name, and an
// unpacked array member is indexed like any other array).
//
// It read back nothing at all. Not a wrong element -- nothing:
//
//     typedef struct { int arr[4]; int tag; } S;
//     S s;  s.tag = 7;
//     for (int i = 0; i < 4; i++) s.arr[i] = 200 + i;
//     $display("%0d %0d %0d %0d", s.arr[0], s.arr[1], s.arr[2], s.arr[3]);
//     // printed  32 32 32 32
//
// 32 is `int''s width. The r-value elaboration of an indexed struct
// member handled only a bit/part-select of a PACKED member and returned
// nil for anything else, so the whole expression disappeared: an
// assignment `t = s.arr[2];' was dropped from the netlist entirely, and
// a $display argument came out blank -- which is what left the format
// string reading a stray width. `foreach (s.arr[i])' went further and
// tripped `vvp.tgt: Unable to draw statement type 0'.
//
// The write side was correct all along (%store/prop/v/i, with a real
// index), and the runtime already had the matching indexed read opcode
// %prop/v/i -- it was simply never emitted. The member is one property
// holding the whole array, so an element read is the property read WITH
// a word index, the same shape a class property already used.
//
// A scalar member of the same struct was correct, and so was a plain
// unpacked array outside a struct. Both are controls here.
//
// A DYNAMIC ARRAY or QUEUE member needs a different shape again: that
// member slot holds a container OBJECT rather than inline storage, so a
// slot-indexed read would fetch the handle's bit pattern instead of an
// element. Those build the container read plus an element select --
// `%prop/obj' + `%load/qo/v' -- which is what a class-property
// container already did. Both are covered below.
//
// The array-QUERY functions are a third case. `$size(s.arr)' returned x
// because the query special-case only recognised a dynamic-array
// property, never a fixed one, so the argument fell through to the
// generic path and reached $size as a plain 32-bit value. A struct
// member's shape is known at elaboration time, so the whole family is
// now folded to a constant there.
//
// STILL OPEN (deliberately not claimed by this test): passing `s.arr'
// to an open-array formal -- SystemVerilog or DPI -- still delivers an
// empty array. That one is genuinely larger: the member is stored as
// inline vector words, the port wants a dynamic-array OBJECT, and there
// is no runtime primitive that builds one from the other. Also
// open: a queue member's METHODS (`s.q.push_back(x)') do not resolve as
// method calls at all -- "Enable of unknown task" -- which is why the
// queue below is filled with an assignment pattern.

module main;

  typedef struct { int arr[4]; byte b[3]; int tag; } S;
  typedef struct { int da[]; int q[$]; int tag; } Cont;
  typedef struct { int asc[4]; int desc[3:0]; } Shape;
  typedef struct { S inner; int arr2[2]; } Outer;

  S     s;
  Outer o;
  S     sa[2];
  int   plain[4];
  Cont  ct;
  Shape sh;
  int   plain_da[];
  int   plain_desc[3:0];

  int k = 1;
  int fails = 0;

  task chk(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got %0d want %0d", what, got, want);
    end
  endtask

  initial begin
    for (int i = 0; i < 4; i++) begin
      s.arr[i]         = 200 + i;
      o.inner.arr[i]   = 300 + i;
      sa[1].arr[i]     = 500 + i;
      plain[i]         = 600 + i;
    end
    for (int i = 0; i < 3; i++) s.b[i] = 8'(10 + i);
    for (int i = 0; i < 2; i++) o.arr2[i] = 400 + i;
    s.tag = 7;

    // ---- the element read, in each form it can appear in ----
    chk("constant index",                 s.arr[2],        202);
    chk("variable index",                 s.arr[k],        201);
    chk("expression index",               s.arr[k+1],      202);

    begin
      int t, u;
      t = s.arr[2];                       // assignment r-value
      u = s.arr[2] + 1;                   // sub-expression
      chk("as an assignment r-value",     t,               202);
      chk("inside an expression",         u,               203);
    end

    // ---- a narrower element type ----
    chk("a byte member's element",        int'(s.b[1]),     11);

    // ---- nesting ----
    chk("a member of a nested struct",    o.inner.arr[3],  303);
    chk("a member beside a nested struct", o.arr2[1],      401);
    chk("a member of an array of structs", sa[1].arr[2],   502);

    // ---- iteration, which used to be a codegen error ----
    begin
      automatic int t = 0;
      foreach (s.arr[i]) t += s.arr[i];
      chk("foreach over the member",      t,               806);
    end

    // ---- the write side, read back through the fixed read ----
    s.arr[k] = 999;
    chk("write through a variable index", s.arr[1],        999);
    chk("its neighbour is untouched",     s.arr[0],        200);

    // ---- a dynamic array member, and a queue member ----
    //
    // These hold a container object in the member slot rather than
    // inline storage, so they take the container-read + element-select
    // shape rather than the slot-indexed one. Reading them used to be
    // rejected outright.
    ct.da = new[3];
    ct.da[0] = 10; ct.da[1] = 20; ct.da[2] = 30;
    ct.q = '{5, 6, 7};
    ct.tag = 4;

    chk("dynamic array member: size",     ct.da.size(),      3);
    chk("dynamic array member [0]",       ct.da[0],         10);
    chk("dynamic array member [1]",       ct.da[1],         20);
    chk("dynamic array member [2]",       ct.da[2],         30);
    chk("dynamic array member, var index", ct.da[k],        20);
    chk("queue member: size",             ct.q.size(),       3);
    chk("queue member [1]",               ct.q[1],           6);
    chk("the scalar beside them",         ct.tag,            4);

    plain_da = new[2];
    plain_da[1] = 77;
    chk("control: a plain dynamic array", plain_da[1],      77);

    // ---- the array-query functions on a member ----
    chk("$size  on a member",             $size(sh.asc),     4);
    chk("$high  on a member",             $high(sh.asc),     3);
    chk("$low   on a member",             $low(sh.asc),      0);
    chk("$left  on a member",             $left(sh.asc),     0);
    chk("$right on a member",             $right(sh.asc),    3);
    chk("$size  on a descending member",  $size(sh.desc),    4);
    chk("$left  on a descending member",  $left(sh.desc),    3);
    chk("$right on a descending member",  $right(sh.desc),   0);
    chk("$size  on a darray member",      $size(ct.da),      3);
    chk("control: $size of a plain array", $size(plain),     4);
    chk("control: $left of a plain desc",  $left(plain_desc), 3);

    // ---- controls: the shapes that were always correct ----
    chk("control: a scalar member",       s.tag,             7);
    chk("control: a plain unpacked array", plain[2],       602);

    if (fails == 0) $display("PASSED");
    else            $display("FAILED (%0d)", fails);
    $finish(0);
  end

endmodule
