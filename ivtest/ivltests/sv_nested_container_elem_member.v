// Member access through stacked positional container selects:
// qq[i][j].x for queue-of-queue with struct and class elements, plus
// the container literal of struct literals that seeds them. Pre-fix
// (recovery D13) the member access was a hard "does not have a field
// named" elaboration error, and the nested struct-literal push
// created the inner queue with a garbage element encoding, silently
// dropping every element.
typedef struct { int x; int y; } pt_t;

module main;
  class C;
    int v;
    function new(int a); v = a; endfunction
  endclass

  pt_t sq[$][$];
  C cq[$][$];
  int fails = 0;

  initial begin
    // struct elements via a nested pattern literal
    sq.push_back('{'{x:1,y:10}, '{x:2,y:20}});
    begin
      pt_t inner[$];
      pt_t e;
      e.x = 3; e.y = 30;
      inner.push_back(e);
      sq.push_back(inner);
    end
    if (sq[0].size() !== 2) begin fails++; $display("FAILED: sq0 size %0d", sq[0].size()); end
    if (sq[0][0].x !== 1 || sq[0][1].x !== 2) begin
      fails++; $display("FAILED: sq0 members %0d %0d", sq[0][0].x, sq[0][1].x);
    end
    if (sq[0][1].y !== 20) begin fails++; $display("FAILED: sq0 y %0d", sq[0][1].y); end
    if (sq[1][0].x !== 3) begin fails++; $display("FAILED: sq1 %0d", sq[1][0].x); end

    // class-handle elements
    begin
      C inner[$];
      C h;
      h = new(1); inner.push_back(h);
      h = new(2); inner.push_back(h);
      cq.push_back(inner);
      inner = {};
      h = new(3); inner.push_back(h);
      cq.push_back(inner);
    end
    if (cq[0][0].v !== 1 || cq[0][1].v !== 2 || cq[1][0].v !== 3) begin
      fails++; $display("FAILED: cq %0d %0d %0d", cq[0][0].v, cq[0][1].v, cq[1][0].v);
    end

    // variable indices
    begin
      int i = 0, j = 1;
      if (sq[i][j].x !== 2) begin fails++; $display("FAILED: var idx %0d", sq[i][j].x); end
    end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
