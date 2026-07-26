// M1C-4: an UNPACKED ARRAY member of an interface, reached through a
// VIRTUAL interface.
//
// A virtual interface handle resolves each member of the interface class
// type to a slot backed by the instance's VPI handle. An unpacked array's
// handle is a `__vpiArray', not a `__vpiSignal', and the slot resolver
// skipped anything that was not a signal / real / string / base variable
// -- so an array member got no slot at all. Reads returned an empty value
// (`x') and writes returned early and were DISCARDED, with no diagnostic
// and a clean exit. The same member accessed directly through the
// instance was correct throughout, and so was every scalar member through
// the same handle, which is what kept this hidden.
//
// The write is the dangerous half: a driver driving an interface array
// through a virtual interface -- the ordinary UVM shape -- silently drove
// nothing.
//
// An array slot now resolves, and the element index selects the word:
// `vif.arr[i]' reads and writes the instance's array. Reals and strings
// took the same route (their accessors discarded the index outright,
// `(void)idx'), and so did OBJECT elements -- an unpacked array of
// structs read as null through a handle, so `vif.sarr[i].field' read
// zero while the same access through the instance was correct. All are
// covered here.
//
// Against the pre-fix compiler every `vif ...' line below read x / 0 / ""
// and every write through the handle left the instance unchanged.

interface bus_if;
  typedef struct { bit [3:0] hi; int lo; } elem_t;

  bit [7:0]      data;         // scalar control: always worked
  bit [7:0]      arr[4];       // unpacked array of packed
  bit [3:0][3:0] pk;           // packed array member: a single slot
  int            iarr[2];
  real           rarr[2];
  string         sarr[2];
  bit [7:0]      m2[2][2];     // 2-D unpacked
  elem_t         earr[2];      // OBJECT-element array (unpacked struct)
endinterface

module main;

  bus_if sif();
  virtual bus_if vif;

  int k = 1;
  int fails = 0;

  task chk(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got %0d want %0d", what, got, want);
    end
  endtask

  initial begin
    sif.data = 8'd7;
    for (int i = 0; i < 4; i++) sif.arr[i] = i + 80;
    sif.pk = 16'h1234;
    for (int i = 0; i < 2; i++) begin
      sif.iarr[i] = i + 5;
      sif.rarr[i] = i + 0.5;
      sif.sarr[i] = (i == 0) ? "zero" : "one";
    end
    sif.m2[1][1] = 8'd77;

    vif = sif;

    // ---- reads through the handle ----
    chk("scalar member",              vif.data,      7);
    chk("packed array member",        vif.pk,        16'h1234);
    chk("array member, const index",  vif.arr[2],    82);
    chk("array member, var index",    vif.arr[k],    81);
    chk("int array member",           vif.iarr[k],   6);
    chk("2-D array member",           vif.m2[1][1],  77);
    chk("array member bit select",    vif.arr[k][0], 1);

    if (vif.rarr[k] != 1.5) begin
      fails++;
      $display("FAILED -- real array member: got %f want 1.5", vif.rarr[k]);
    end
    if (vif.sarr[k] != "one") begin
      fails++;
      $display("FAILED -- string array member: got \"%s\" want \"one\"", vif.sarr[k]);
    end

    // ---- writes through the handle land on the instance ----
    vif.arr[2] = 8'd90;
    chk("array write, const index", sif.arr[2], 90);
    vif.arr[k] = 8'd91;
    chk("array write, var index",   sif.arr[1], 91);
    vif.arr[k][3:0] = 4'h0;
    chk("array element part write", sif.arr[1], 8'h50);
    vif.iarr[k] = 7;
    chk("int array write",          sif.iarr[1], 7);
    vif.m2[1][1] = 8'd88;
    chk("2-D array write",          sif.m2[1][1], 88);
    vif.data = 8'd9;
    chk("scalar write still works",  sif.data, 9);

    vif.rarr[k] = 2.5;
    if (sif.rarr[1] != 2.5) begin
      fails++;
      $display("FAILED -- real array write: instance has %f want 2.5", sif.rarr[1]);
    end
    vif.sarr[k] = "two";
    if (sif.sarr[1] != "two") begin
      fails++;
      $display("FAILED -- string array write: instance has \"%s\" want \"two\"", sif.sarr[1]);
    end

    // An OBJECT-element array member -- an unpacked array of structs.
    // Its slot resolves the same way; the element index selects the word,
    // and the member is then read out of that element. This read as null
    // (member reads gave 0) while the same access through the instance
    // was correct.
    vif.earr[k].hi = 4'h9;
    vif.earr[k].lo = 55;
    chk("struct array member write, hi", sif.earr[1].hi, 4'h9);
    chk("struct array member write, lo", sif.earr[1].lo, 55);
    chk("struct array member read",      vif.earr[k].hi, 4'h9);
    sif.earr[0].hi = 4'h3;
    chk("struct array instance write seen through handle", vif.earr[0].hi, 4'h3);

    // A write through the instance must be visible through the handle.
    sif.arr[3] = 8'd44;
    chk("instance write seen through handle", vif.arr[3], 44);

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
