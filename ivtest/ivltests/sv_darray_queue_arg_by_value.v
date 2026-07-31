// IEEE 1800-2017 13.5.1: a subroutine argument that is not `ref' is
// passed BY VALUE. A dynamic array and a queue are value containers
// (7.4, 7.5), not handles -- unlike a class, which IS a reference.
//
// The argument path pushed the caller's container and stored it straight
// into the formal, so the formal and the actual were the same object. A
// callee that wrote its own INPUT formal wrote through to the caller's
// variable, at exit 0 with no diagnostic. UVM passes queues into
// functions constantly.
//
// Plain assignment always got this right (`b = a' emits %dup/obj,
// %store/obj, %pop/obj), which is what makes the divergence a defect
// rather than a missing feature -- so this test checks the two against
// each other as well as against literal expectations.
//
// The `ref' cases are here to pin the other side of the line: they MUST
// still write through (13.5.2). A fix that copied everything would pass
// the by-value checks and silently break these.
module sv_darray_queue_arg_by_value;

  integer errors = 0;

  task check(input integer got, input integer exp, input [511:0] what);
    begin
      if (got !== exp) begin
        $display("MISMATCH %0s: got %0h expected %0h", what, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  // --- callees that clobber their own formal ---
  function automatic int fq_clobber(int m [$]);
    m[0] = 32'hff;
    return m[0];
  endfunction

  function automatic int fd_clobber(int m []);
    m[0] = 32'hff;
    return m[0];
  endfunction

  task automatic tq_clobber(int m [$]);
    m[0] = 32'hee;
  endtask

  // --- ref callees, which must write through ---
  function automatic int fq_ref(ref int m [$]);
    m[0] = 32'hff;
    return m[0];
  endfunction

  task automatic tq_ref(ref int m [$]);
    m[0] = 32'hee;
  endtask

  // --- nested call: the outer actual must survive the inner call ---
  function automatic int fq_outer(int m [$]);
    void'(fq_clobber(m));      // inner clobbers its own copy
    return m[0];               // outer's copy must be untouched
  endfunction

  int q [$];
  int d [];
  int qa [$], qb [$];
  int r;

  initial begin
    // ---------- queue, non-ref function formal ----------
    q.delete(); q.push_back(32'h11); q.push_back(32'h22);
    r = fq_clobber(q);
    check(r,    32'hff, "callee sees its own write");
    check(q[0], 32'h11, "queue actual after non-ref function");

    // ---------- dynamic array, non-ref function formal ----------
    d = new[2]; d[0] = 32'h11; d[1] = 32'h22;
    r = fd_clobber(d);
    check(r,    32'hff, "darray callee sees its own write");
    check(d[0], 32'h11, "darray actual after non-ref function");

    // ---------- queue, non-ref TASK formal ----------
    q.delete(); q.push_back(32'h11);
    tq_clobber(q);
    check(q[0], 32'h11, "queue actual after non-ref task");

    // ---------- ref must STILL write through ----------
    q.delete(); q.push_back(32'h11);
    r = fq_ref(q);
    check(r,    32'hff, "ref function return");
    check(q[0], 32'hff, "ref function wrote through");

    q.delete(); q.push_back(32'h11);
    tq_ref(q);
    check(q[0], 32'hee, "ref task wrote through");

    // ---------- nested calls each get their own copy ----------
    q.delete(); q.push_back(32'h11);
    r = fq_outer(q);
    check(r,    32'h11, "outer copy survived the inner call");
    check(q[0], 32'h11, "actual survived nested calls");

    // ---------- plain assignment must still copy ----------
    qa.delete(); qa.push_back(32'h11);
    qb = qa;
    qb[0] = 32'hff;
    check(qa[0], 32'h11, "assignment still copies");

    // ---------- the two spellings must agree ----------
    q.delete();  q.push_back(32'h33);
    qa.delete(); qa.push_back(32'h33);
    void'(fq_clobber(q));   // argument copy
    qb = qa; qb[0] = 32'hff; // assignment copy
    check(q[0], qa[0], "argument copy vs assignment copy");

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED -- %0d mismatches", errors);
    $finish;
  end

endmodule
