// Indexed access to container/array members of a struct held in a
// CLASS property: h.f.da[i], h.f.q[i], h.f.aa[key], h.f.arr[i].
// Pre-fix these were a hard "sorry: this form of indexed struct
// member access is not yet supported" on the READ side (recovery D8)
// while the write side elaborated — so a write+readback pair could
// not even compile.
module main;
  typedef struct {
    int da[];
    int q[$];
    int aa[string];
    int arr[3];
    int scalar;
  } rec_t;

  class Holder;
    rec_t f;
  endclass

  Holder h;
  int fails = 0;

  initial begin
    h = new;

    // darray member
    h.f.da = new[2];
    h.f.da[0] = 10;
    h.f.da[1] = 11;
    if (h.f.da[0] !== 10 || h.f.da[1] !== 11) begin
      fails++; $display("FAILED: da %0d %0d", h.f.da[0], h.f.da[1]);
    end
    if (h.f.da.size() !== 2) begin fails++; $display("FAILED: da.size=%0d", h.f.da.size()); end

    // queue member
    h.f.q.push_back(5);
    h.f.q.push_back(6);
    if (h.f.q[0] !== 5 || h.f.q[1] !== 6) begin
      fails++; $display("FAILED: q %0d %0d", h.f.q[0], h.f.q[1]);
    end

    // assoc member
    h.f.aa["k"] = 100;
    if (h.f.aa["k"] !== 100) begin fails++; $display("FAILED: aa %0d", h.f.aa["k"]); end

    // fixed unpacked-array member
    h.f.arr[0] = 7;
    h.f.arr[2] = 9;
    if (h.f.arr[0] !== 7 || h.f.arr[2] !== 9) begin
      fails++; $display("FAILED: arr %0d %0d", h.f.arr[0], h.f.arr[2]);
    end

    // variable index and expression context
    begin
      int i = 1;
      int sum;
      sum = h.f.da[0] + h.f.da[i] + h.f.q[i];
      if (sum !== 27) begin fails++; $display("FAILED: sum=%0d", sum); end
    end

    // scalar member beside them stays correct
    h.f.scalar = 3;
    if (h.f.scalar !== 3) begin fails++; $display("FAILED: scalar=%0d", h.f.scalar); end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
