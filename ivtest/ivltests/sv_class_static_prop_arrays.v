// Static class properties of array/container types: element writes,
// element reads, whole-pattern writes, and passing elements as task
// arguments — through both the handle form (h.sarr[i]) and the scoped
// form (Class::sarr[i]). Pre-fix (recovery D9/D10 family): a static
// FIXED-ARRAY property was created as a single-word signal, so the
// runtime saw a scalar while codegen addressed an array — whole-
// pattern writes failed at RUNTIME ("unresolved %store/vec4a") with
// exit 0 and zero reads; element writes were a compile error ("cannot
// be implicitly cast"); container-element reads as arguments errored
// ("unpacked aggregate cannot be assigned to a scalar target").
module main;
  class holder;
    static int sarr[4];
    static int sda[];
    static int sq[$];
    static int saa[string];
    static int scalar;
  endclass

  holder h;
  int fails = 0;

  task automatic take(input int v, input int exp, string what);
    if (v !== exp) begin fails++; $display("FAILED: %s arg %0d exp %0d", what, v, exp); end
  endtask

  initial begin
    h = new;

    // whole-pattern write then element reads (both access forms)
    holder::sarr = '{10, 20, 30, 40};
    if (holder::sarr[0] !== 10 || holder::sarr[2] !== 30) begin
      fails++; $display("FAILED: pattern write %0d %0d", holder::sarr[0], holder::sarr[2]);
    end
    if (h.sarr[3] !== 40) begin fails++; $display("FAILED: handle read %0d", h.sarr[3]); end

    // element writes, both forms
    holder::sarr[1] = 99;
    h.sarr[2] = 88;
    if (holder::sarr[1] !== 99 || holder::sarr[2] !== 88) begin
      fails++; $display("FAILED: elem writes %0d %0d", holder::sarr[1], holder::sarr[2]);
    end

    // variable index
    begin
      int i = 3;
      if (h.sarr[i] !== 40) begin fails++; $display("FAILED: var idx %0d", h.sarr[i]); end
      holder::sarr[i] = 44;
      if (h.sarr[3] !== 44) begin fails++; $display("FAILED: var idx write %0d", h.sarr[3]); end
    end

    // darray property: new + element write + read + arg
    holder::sda = new[2];
    holder::sda[0] = 3;
    h.sda[1] = 5;
    if (holder::sda[0] !== 3 || holder::sda[1] !== 5) begin
      fails++; $display("FAILED: darray %0d %0d", holder::sda[0], holder::sda[1]);
    end
    take(holder::sda[0], 3, "darray-elem");

    // queue property: push + element read/write + arg
    holder::sq.push_back(7);
    holder::sq.push_back(8);
    if (h.sq[1] !== 8) begin fails++; $display("FAILED: queue read %0d", h.sq[1]); end
    holder::sq[0] = 70;
    if (holder::sq[0] !== 70) begin fails++; $display("FAILED: queue write %0d", holder::sq[0]); end
    take(h.sq[0], 70, "queue-elem");

    // assoc property: keyed write/read + arg
    holder::saa["k"] = 3;
    if (holder::saa["k"] !== 3) begin fails++; $display("FAILED: assoc %0d", holder::saa["k"]); end
    take(holder::saa["k"], 3, "assoc-elem");

    // fixed-array element as arg
    take(h.sarr[1], 99, "arr-elem");

    // scalar control beside them
    holder::scalar = 6;
    if (h.scalar !== 6) begin fails++; $display("FAILED: scalar %0d", h.scalar); end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
