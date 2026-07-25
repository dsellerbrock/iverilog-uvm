// M1C-1: a named block scope is elaborated ONCE per parent scope.
//
// Some paths reach the same body twice -- a class constructor at $unit
// scope is one -- and PBlock::elaborate_scope built a SECOND NetScope for
// the same name under the same parent every time. That orphaned the
// first: the signature pass had declared the block's locals into the
// scope it saw, and the body was then elaborated against the newer, empty
// one.
//
// `foreach' is where it surfaced, because the loop variable lives in the
// implicit block scope the parser pushes for it. Inside a $unit-scope
// class constructor, over a RUNTIME-SIZED array (dynamic array or queue,
// property or local), elaboration reached elaborate_runtime_array_ with
// no loop-variable signal and ABORTED the compiler:
//
//   assert: elaborate.cc:11284: failed assertion idx_sig
//
// A fixed-size array was unaffected -- it takes the compile-time-bounds
// path, which never looks the index signal up -- and so was every
// non-constructor method, which is why this survived so long.
//
// Against the pre-fix compiler this file does not compile at all.

class leaf;
  int f;
  function new(int v = 0); f = v; endfunction
endclass

// dynamic-array property, sized and filled in the constructor
class darray_prop;
  int d[];
  function new();
    d = new[4];
    foreach (d[i]) d[i] = i + 1;
  endfunction
endclass

// queue property, filled in the constructor
class queue_prop;
  int q[$];
  function new();
    for (int j = 0; j < 4; j++) q.push_back(j + 10);
    foreach (q[i]) q[i] = q[i] + 100;
  endfunction
endclass

// runtime-sized LOCAL of the constructor
class local_darray;
  int out[];
  function new();
    int tmp[];
    tmp = new[4];
    foreach (tmp[i]) tmp[i] = i + 20;
    out = tmp;
  endfunction
endclass

// associative-array property, iterated in the constructor
class assoc_prop;
  int a[string];
  int total;
  function new();
    a["x"] = 1;
    a["y"] = 2;
    total = 0;
    foreach (a[k]) total += a[k];
  endfunction
endclass

// nested foreach in the constructor: both index variables live in
// separate implicit block scopes.
class nested_foreach;
  int m[];
  int sum;
  function new();
    m = new[3];
    foreach (m[i]) m[i] = i + 1;
    sum = 0;
    foreach (m[i]) begin
      foreach (m[j]) sum += m[i] * m[j];
    end
  endfunction
endclass

// a fixed-size array in the constructor kept working throughout: it is
// the control that shows the defect was specific to the runtime path.
class fixed_prop;
  int s[4];
  function new();
    foreach (s[i]) s[i] = i + 30;
  endfunction
endclass

module main;

  darray_prop    dp;
  queue_prop     qp;
  local_darray   lp;
  assoc_prop     ap;
  nested_foreach np;
  fixed_prop     fp;

  int fails = 0;

  initial begin
    dp = new(); qp = new(); lp = new();
    ap = new(); np = new(); fp = new();

    for (int i = 0; i < 4; i++)
      if (dp.d[i] != i + 1) begin
        fails++;
        $display("FAILED -- darray property d[%0d]=%0d (want %0d)", i, dp.d[i], i + 1);
      end

    for (int i = 0; i < 4; i++)
      if (qp.q[i] != i + 110) begin
        fails++;
        $display("FAILED -- queue property q[%0d]=%0d (want %0d)", i, qp.q[i], i + 110);
      end

    for (int i = 0; i < 4; i++)
      if (lp.out[i] != i + 20) begin
        fails++;
        $display("FAILED -- constructor-local darray out[%0d]=%0d (want %0d)",
                 i, lp.out[i], i + 20);
      end

    if (ap.total != 3) begin
      fails++;
      $display("FAILED -- assoc property total=%0d (want 3)", ap.total);
    end

    // (1+2+3)^2 = 36
    if (np.sum != 36) begin
      fails++;
      $display("FAILED -- nested foreach sum=%0d (want 36)", np.sum);
    end

    for (int i = 0; i < 4; i++)
      if (fp.s[i] != i + 30) begin
        fails++;
        $display("FAILED -- fixed array s[%0d]=%0d (want %0d)", i, fp.s[i], i + 30);
      end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
