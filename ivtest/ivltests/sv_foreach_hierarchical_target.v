// M1C/M5: `foreach' over a HIERARCHICAL target — an array member of an
// interface instance, `foreach (sif.arr[i])'.
//
// A multi-component foreach target was routed through the expression
// path, which cannot produce a whole unpacked array for a hierarchical
// name, so this failed to elaborate:
//
//   error: Array sif.arr needs an array index here.
//   error: Unable to resolve foreach target sif.arr in scope main.$ivl_foreach0.
//
// while the two neighbouring shapes both worked: `foreach (h.a[i])' over
// a class property, and `foreach (vif.arr[i])' through a virtual
// interface handle. Three ways of naming the same kind of thing, and only
// the one that resolves to an ordinary signal was rejected.
//
// A hierarchical path that resolves to a SIGNAL now takes the same route
// as a plain local array. Paths that do not resolve to a signal (class
// properties, virtual-interface members) keep the expression route.

interface bus_if;
  bit [7:0] arr[4];
  int       wide[2][3];
  bit [7:0] q[$];
endinterface

class holder;
  bit [7:0] a[4];
endclass

module main;

  bus_if sif();
  virtual bus_if vif;
  holder h;

  bit [7:0] local_arr[4];

  int fails = 0;
  int sum;

  initial begin
    h = new();
    for (int i = 0; i < 4; i++) begin
      sif.arr[i]   = i + 1;
      h.a[i]       = i + 1;
      local_arr[i] = i + 1;
    end
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        sif.wide[i][j] = (i * 3) + j;
    sif.q.push_back(8'd10);
    sif.q.push_back(8'd20);

    // control 1: a plain local array
    sum = 0;
    foreach (local_arr[i]) sum += local_arr[i];
    if (sum != 10) begin
      fails++; $display("FAILED -- local array foreach sum=%0d (want 10)", sum);
    end

    // control 2: a class property
    sum = 0;
    foreach (h.a[i]) sum += h.a[i];
    if (sum != 10) begin
      fails++; $display("FAILED -- class property foreach sum=%0d (want 10)", sum);
    end

    // control 3: through a virtual interface handle
    vif = sif;
    sum = 0;
    foreach (vif.arr[i]) sum += vif.arr[i];
    if (sum != 10) begin
      fails++; $display("FAILED -- virtual interface foreach sum=%0d (want 10)", sum);
    end

    // the shape under test: a hierarchical name into the instance
    sum = 0;
    foreach (sif.arr[i]) sum += sif.arr[i];
    if (sum != 10) begin
      fails++; $display("FAILED -- hierarchical foreach sum=%0d (want 10)", sum);
    end

    // writing through the loop must reach the instance
    foreach (sif.arr[i]) sif.arr[i] = i + 100;
    for (int i = 0; i < 4; i++)
      if (sif.arr[i] != i + 100) begin
        fails++;
        $display("FAILED -- hierarchical foreach write arr[%0d]=%0d (want %0d)",
                 i, sif.arr[i], i + 100);
      end

    // two dimensions
    sum = 0;
    foreach (sif.wide[i,j]) sum += sif.wide[i][j];
    if (sum != 15) begin
      fails++; $display("FAILED -- 2-D hierarchical foreach sum=%0d (want 15)", sum);
    end

    // a runtime-sized member: the size comes from the container
    sum = 0;
    foreach (sif.q[i]) sum += sif.q[i];
    if (sum != 30) begin
      fails++; $display("FAILED -- hierarchical queue foreach sum=%0d (want 30)", sum);
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
