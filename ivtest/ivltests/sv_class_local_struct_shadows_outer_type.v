class a;
  static function int marker;
    return 7;
  endfunction
endclass

class resource_types;
  typedef struct {
    int unsigned read_count;
    int unsigned write_count;
  } access_t;
endclass

class resource_debug;
  resource_types::access_t access[string];
endclass

class resource_base;
  resource_debug dbg;

  function new;
    dbg = new;
  endfunction
endclass

class resource_pool;
  function int count(resource_base rsrc_iter);
    resource_types::access_t a;
    int reads = 0;
    int writes = 0;

    foreach (rsrc_iter.dbg.access[str]) begin
      a = rsrc_iter.dbg.access[str];
      reads += a.read_count;
      writes += a.write_count;
    end

    return reads + writes;
  endfunction
endclass

module test;
  initial begin
    resource_base r;
    resource_pool p;
    resource_types::access_t tmp;
    r = new;
    p = new;
    tmp.read_count = 2;
    tmp.write_count = 3;
    r.dbg.access["x"] = tmp;
    if (p.count(r) != 5) begin
      $display("FAILED count=%0d", p.count(r));
      $finish(1);
    end
    if (a::marker() != 7) begin
      $display("FAILED scoped marker=%0d", a::marker());
      $finish(1);
    end
    $display("PASSED");
  end
endmodule
