typedef struct {
  bit [7:0] word;
} rollback_payload_t;

class rollback_leaf #(int TAG = 0);
  static randc bit [1:0] shared;
  randc bit [1:0] cyc;
  rand bit [7:0] data;
  bit force_fail;

  constraint fail_c {
    if (force_fail) data == 8'd0;
    if (force_fail) data == 8'd1;
  }
endclass

class rollback_parent #(int TAG = 0);
  rand rollback_leaf#(TAG) child;
  rand rollback_payload_t record;
  rand bit [7:0] entries[string];
  rand rollback_leaf#(TAG) object_entries[string];
  rand bit root;

  function new;
    child = new;
    object_entries["leaf"] = new;
  endfunction
endclass

class rollback_bad_leaf;
  rand bit [7:0] data;
  constraint impossible_c {
    data == 8'd0;
    data == 8'd1;
  }
endclass

class rollback_bad_parent;
  rand rollback_bad_leaf child;
  rand bit root;

  function new;
    child = new;
  endfunction
endclass

module test;
  initial begin
    rollback_parent#(0) subject;
    rollback_bad_parent child_failure;
    rollback_leaf#(1) control;
    int status;

    subject = new;
    control = new;
    subject.child.cyc = 2'd0;
    subject.child.data = 8'h11;
    subject.child.shared = 2'd0;
    subject.record.word = 8'h22;
    subject.entries["key"] = 8'h33;
    subject.object_entries["leaf"].cyc = 2'd0;
    subject.object_entries["leaf"].data = 8'h44;
    subject.root = 1'b1;
    subject.srandom(32'h1020_3040);
    subject.child.srandom(32'h1357_2468);
    subject.object_entries["leaf"].srandom(32'h89ab_cdef);

    status = subject.randomize() with { 1'b0; };
    if (status !== 0)
      $fatal(1, "contradictory parent randomize did not fail");
    if (subject.child.cyc !== 2'd0 || subject.child.data !== 8'h11)
      $fatal(1, "parent failure leaked direct child values");
    if (subject.child.shared !== 2'd0)
      $fatal(1, "parent failure leaked canonical static value");
    if (subject.record.word !== 8'h22)
      $fatal(1, "parent failure leaked unpacked-struct value");
    if (subject.entries["key"] !== 8'h33)
      $fatal(1, "parent failure leaked associative entry value");
    if (subject.object_entries["leaf"].cyc !== 2'd0
        || subject.object_entries["leaf"].data !== 8'h44)
      $fatal(1, "parent failure leaked associative child values");
    if (subject.root !== 1'b1)
      $fatal(1, "parent failure leaked root value");

    // Failed outer calls may advance RNG state, but must not consume either
    // instance or canonical-static randc history. Equal seeds and baseline
    // values therefore replay the independent specialization exactly.
    subject.child.force_fail = 1'b0;
    control.force_fail = 1'b0;
    control.cyc = 2'd0;
    control.data = 8'h11;
    control.shared = 2'd0;
    subject.child.srandom(32'h1357_2468);
    control.srandom(32'h1357_2468);
    if (subject.child.randomize() !== 1 || control.randomize() !== 1)
      $fatal(1, "post-rollback history controls failed");
    if (subject.child.cyc !== control.cyc
        || subject.child.data !== control.data
        || subject.child.shared !== control.shared)
      $fatal(1, "parent failure consumed child/static randc history");

    // A failing implicit child solve fails the complete outer graph and
    // leaves every participant at its pre-call value.
    child_failure = new;
    child_failure.child.data = 8'h5a;
    child_failure.root = 1'b1;
    if (child_failure.randomize() !== 0)
      $fatal(1, "child UNSAT was ignored by parent randomize");
    if (child_failure.child.data !== 8'h5a
        || child_failure.root !== 1'b1)
      $fatal(1, "child failure did not roll back the outer graph");

    $display("PASSED");
  end
endmodule
