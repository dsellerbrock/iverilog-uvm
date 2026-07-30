// IEEE 1800-2017 7.9.2: aa.delete() with no arguments removes ALL
// entries -- on a class-property associative array and on a plain
// variable alike. Pre-fix, the class-property form fell into the
// plain-queue delete path, whose typed receiver peek nulls on an assoc
// object: the operation was DROPPED with a generic "null queue"
// warning and the array kept its contents (silent data retention).
// Every stock UVM run hit that ~127 times.
class holder;
  protected int m_count[int];
  function void bump(int key, int v); m_count[key] = v; endfunction
  function void clear_all(); m_count.delete(); endfunction
  function void clear_key(int key); m_count.delete(key); endfunction
  function int sz(); return m_count.size(); endfunction
endclass

module top;
  holder h;
  int m[string];
  int mi[int];
  int fails = 0;
  initial begin
    // Class-property associative array.
    h = new;
    h.bump(1,5); h.bump(2,7);
    if (h.sz() != 2) begin fails++; $display("FAIL: seed size=%0d expect 2", h.sz()); end
    h.clear_key(1);
    if (h.sz() != 1) begin fails++; $display("FAIL: keyed delete size=%0d expect 1", h.sz()); end
    h.clear_all();
    if (h.sz() != 0) begin fails++; $display("FAIL: delete() size=%0d expect 0", h.sz()); end

    // Refill after clearing: the container must still work.
    h.bump(3,9);
    if (h.sz() != 1) begin fails++; $display("FAIL: refill size=%0d expect 1", h.sz()); end

    // Plain associative-array variables, string and int keys.
    m["a"]=1; m["b"]=2; mi[5]=50;
    m.delete("a");
    if (m.size() != 1) begin fails++; $display("FAIL: var keyed delete size=%0d", m.size()); end
    m.delete();
    mi.delete();
    if (m.size() != 0 || mi.size() != 0) begin fails++; $display("FAIL: var delete() m=%0d mi=%0d", m.size(), mi.size()); end

    // delete() on a never-written assoc property: correct no-op, no warning.
    begin
      holder h2 = new;
      h2.clear_all();
      if (h2.sz() != 0) begin fails++; $display("FAIL: empty clear size=%0d", h2.sz()); end
    end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
