// IEEE 1800-2017 13.5.2: an argument passed by reference is not copied.
// "A reference to the original argument is passed to the subroutine",
// so a write through the formal is visible to the caller AT ONCE rather
// than at return, and a read through it sees whatever the caller has
// put there since the call.
//
// `ref' was implemented as copy-in/copy-out. That is observationally
// equivalent only for a subroutine that neither consumes time nor
// shares the variable with anything else -- and it is exactly wrong
// everywhere else, silently:
//
//   * A task forked with `fork ... join_none' that never returns never
//     copied anything out. `fork spin(count); join_none' with
//     `task spin(ref int x); forever #1 x++; endtask' left the caller's
//     count at 0 forever. The argument was not slow to arrive; it never
//     arrived.
//
//   * A caller watching the variable while the subroutine ran saw the
//     old value, and the subroutine reading it saw the value from call
//     time, not the caller's later write.
//
//   * Even with no concurrency at all: a function that writes its ref
//     formal and then reads the SAME variable under its other name read
//     the stale copy.
//
// A ref formal is now a name bound to the caller's variable rather than
// storage of its own (%ref/bind, .ref). An actual that cannot be named
// -- an array element, a class property -- binds to a per-frame
// temporary that is copied in and out, which is what those shapes had
// before and is checked below so that path does not rot.
//
// Real, string and container (dynamic array, queue, fixed array)
// formals still use the copy pair; their reads go through type-specific
// opcodes a bound formal cannot answer. They are exercised here as
// controls, because the change must not disturb them. A class-handle
// formal is ALSO bound now (R25: see sv_ref_arg_object_fork_detach.v),
// because vvp_ref_signal_aa can answer the object accessor interface
// too; that fork/join_none-detach shape is exercised over there.

module main;

  int  fails = 0;

  task chk(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got %0d want %0d", what, got, want);
    end
  endtask

  // ---------------------------------------------------------------
  // 1. a task that never returns
  // ---------------------------------------------------------------
  int live = 0;
  task automatic spin(ref int x);
    forever #1 x++;
  endtask

  // ---------------------------------------------------------------
  // 2. writes visible mid-call, reads see the caller's later write
  // ---------------------------------------------------------------
  int mid = 0;
  task automatic write_wait_write(ref int x);
    x = 42;
    #5;
    x = 43;
  endtask

  int rd_seen = 0;
  task automatic read_late(const ref int x);
    #3;
    rd_seen = x;
  endtask

  // ---------------------------------------------------------------
  // 3. aliasing, with no concurrency at all
  // ---------------------------------------------------------------
  int aliased = 0;
  int alias_saw;
  function automatic void write_then_read_other_name(ref int x);
    x = 5;
    alias_saw = aliased;         // the same object, under its own name
  endfunction

  // ---------------------------------------------------------------
  // 4. the shapes around it
  // ---------------------------------------------------------------
  function automatic void bump(ref int x);
    x = x + 10;
  endfunction

  function automatic void bumpv(ref logic [15:0] v);
    v = v + 16'd10;
  endfunction

  // a ref actual forwarded as another subroutine's ref actual
  function automatic void inner(ref int y); y = y + 1; endfunction
  function automatic void outer(ref int x); inner(x); inner(x); endfunction

  // recursion: each frame binds its own actual
  function automatic int descend(ref int x, input int n);
    if (n == 0) return x;
    x = x + 1;
    return descend(x, n-1);
  endfunction

  // two ref formals naming one variable
  function automatic void both(ref int a, ref int b);
    a = 1;
    b = a + 1;
  endfunction

  // a value-returning function: a different call path from a task
  function automatic int add_and_double(ref int x, input int n);
    x = x + n;
    return x * 2;
  endfunction


  int  arr[4];
  int  vecsrc;
  logic [15:0] vec;
  int  k;

  class C;
    int f;
  endclass
  C c;

  // recursion and concurrency THROUGH the temporary: the actual is an
  // array element every time, so each frame needs its own. A temporary
  // shared between frames would show up as one counter for all of them.
  function automatic int descend_elem(input int i, input int n);
    return descend(arr[i], n);
  endfunction

  task automatic tspin(ref int x, input int n);
    repeat (n) #1 x++;
  endtask

  // ---------------------------------------------------------------
  // 5. the other places a ref formal can live
  // ---------------------------------------------------------------
  //
  // A class method is its own call path, and a VIRTUAL one is another:
  // the call allocates the base method's frame while the override runs
  // in a frame of its own, so the binding has to travel with the
  // formals or the override writes nowhere. A constructor is a third.
  // A static-lifetime subroutine has no frame at all to hold a binding,
  // so its ref formals keep the copy pair -- checked here so that
  // fallback stays wired up.
  class Base;
    virtual task bump_m(ref int x); x = x + 1;  endtask
    virtual function int fbump_m(ref int x); x = x + 2; return x; endfunction
    task spin_m(ref int x); forever #1 x++; endtask
  endclass

  class Derived extends Base;
    virtual task bump_m(ref int x); x = x + 10; endtask
  endclass

  class Ctor;
    function new(ref int x); x = x + 3; endfunction
    static function void sbump(ref int x); x = x + 4; endfunction
  endclass

  // a ref forwarded between two frames that are BOTH still live has to
  // reach past them to the caller's variable
  class Relay;
    task automatic go(ref int x);         spin_relay(x);   endtask
    task automatic spin_relay(ref int x); forever #1 x++;  endtask
  endclass

  task st_task(ref int x);          // static lifetime: no frame
    x = x + 100;
  endtask

  // A part select through a ref formal takes a different opcode from a
  // whole-word store, and reading one through VPI ($display) takes a
  // third; both have to reach the caller's variable like everything else.
  int vpi_saw = -1;
  task automatic part_and_read(ref int x, ref logic [7:0] y);
    vpi_saw = x;                    // read
    x[3:0]  = 4'hF;                 // part write
    y[7:4]  = 4'h3;
  endtask
  logic [7:0] pw = 8'hA5;

  Base    bh;
  Derived dh;
  Ctor    ct;
  Relay   rl_obj;
  int     m_live = 0;
  int     relay_live = 0;

  // ---------------------------------------------------------------
  // controls: types that keep the copy pair
  // ---------------------------------------------------------------
  function automatic void qpush(ref int qq[$]); qq.push_back(9); endfunction
  function automatic void sset(ref string t);   t = "z";         endfunction
  function automatic void rset(ref real r);     r = 2.5;         endfunction
  int    q[$];
  string s = "a";
  real   rl = 0.0;

  initial begin

    // ---- a task that never returns ----
    fork spin(live); join_none
    #6;
    if (live == 0) begin
      fails++;
      $display("FAILED -- a ref argument to a task that never returns was never written");
    end

    // ---- mid-call visibility ----
    fork write_wait_write(mid); join_none
    #1;
    chk("a ref write is visible before the subroutine returns", mid, 42);
    #10;
    chk("and the later write lands too", mid, 43);

    // ---- a ref read sees the caller's update ----
    k = 1;
    fork read_late(k); join_none
    #1 k = 99;
    #5;
    chk("a ref read sees what the caller wrote after the call", rd_seen, 99);

    // ---- aliasing, no concurrency ----
    write_then_read_other_name(aliased);
    chk("a ref write is visible through the variable's own name", alias_saw, 5);

    // ---- an array element actual: bound to a temporary ----
    arr[2] = 5;
    bump(arr[2]);
    chk("array element actual", arr[2], 15);
    chk("its neighbour is untouched", arr[1], 0);

    // ---- a class property actual ----
    c = new();
    c.f = 7;
    bump(c.f);
    chk("class property actual", c.f, 17);

    // ---- a whole packed vector ----
    vec = 16'd3;
    bumpv(vec);
    chk("packed vector formal", int'(vec), 13);

    // ---- forwarded ref ----
    vecsrc = 0;
    outer(vecsrc);
    chk("a ref actual forwarded as another ref actual", vecsrc, 2);

    // ---- recursion ----
    k = 0;
    chk("recursive ref: return", descend(k, 5), 5);
    chk("recursive ref: the variable", k, 5);

    // ---- two formals, one variable ----
    k = 0;
    both(k, k);
    chk("two ref formals naming one variable", k, 2);

    // ---- a value-returning function ----
    k = 3;
    chk("value-returning function: return", add_and_double(k, 4), 14);
    chk("value-returning function: the variable", k, 7);

    // ---- recursion and concurrency through the temporary ----
    arr[0] = 0;
    chk("recursion through the temporary: return", descend_elem(0, 5), 5);
    chk("recursion through the temporary: the element", arr[0], 5);

    arr[1] = 0; arr[2] = 0; arr[3] = 0;
    fork tspin(arr[1], 3); join_none
    fork tspin(arr[2], 3); join_none
    #10;
    chk("concurrent calls through the temporary: arr[1]", arr[1], 3);
    chk("concurrent calls through the temporary: arr[2]", arr[2], 3);
    chk("and a bystander element",                        arr[3], 0);

    // ---- a class method, and a virtual one ----
    bh = new();
    k = 0; bh.bump_m(k);
    chk("a ref formal of a class method", k, 1);

    k = 0;
    chk("a ref formal of a class function: return", bh.fbump_m(k), 2);
    chk("a ref formal of a class function: the variable", k, 2);

    dh = new(); bh = dh;
    k = 0; bh.bump_m(k);
    chk("the OVERRIDE's ref formal after virtual dispatch", k, 10);

    fork bh.spin_m(m_live); join_none
    #4;
    if (m_live == 0) begin
      fails++;
      $display("FAILED -- a class method's ref argument never arrived");
    end

    // ---- a constructor, and a static class function ----
    k = 0; ct = new(k);
    chk("a ref formal of a constructor", k, 3);
    k = 0; Ctor::sbump(k);
    chk("a ref formal of a static class function", k, 4);

    // ---- forwarded between two frames that are both still live ----
    rl_obj = new();
    fork rl_obj.go(relay_live); join_none
    #4;
    if (relay_live == 0) begin
      fails++;
      $display("FAILED -- a ref forwarded through two live frames never reached the caller");
    end

    // ---- part selects, and a read that goes through VPI ----
    k = 7;
    part_and_read(k, pw);
    chk("a ref formal read back at the call site", vpi_saw, 7);
    chk("a part write through a ref formal",       k,       15);
    chk("a part write through a ref vector",       int'(pw), 8'h35);

    // ---- a static-lifetime subroutine: the copy pair ----
    k = 0; st_task(k);
    chk("a ref formal of a static-lifetime task", k, 100);

    // ---- controls ----
    qpush(q);
    chk("ref queue still works", q.size(), 1);
    sset(s);
    if (s != "z") begin
      fails++;
      $display("FAILED -- ref string: got %s want z", s);
    end
    rset(rl);
    if (rl != 2.5) begin
      fails++;
      $display("FAILED -- ref real: got %f want 2.5", rl);
    end

    if (fails == 0) $display("PASSED");
    else            $display("FAILED (%0d)", fails);
    $finish(0);
  end

endmodule
