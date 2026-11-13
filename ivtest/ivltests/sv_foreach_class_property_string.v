// IEEE 1800-2017/2023 12.7.3: foreach over a string iterates its characters,
// and 6.16: an index into a string selects a byte. Covers a property seen
// through a handle, through implicit `this' in a method, and inherited from
// a base class (the uvm_component::get_depth() shape).
class base_t;
  string name = "a.b.c";
endclass

class c_t extends base_t;
  function int unsigned depth();
    if (name == "") return 0;
    depth = 1;
    foreach (name[i])
      if (name[i] == ".") ++depth;
  endfunction

  function int own_count();
    foreach (name[i]) begin
      if (name[i] != name.getc(i)) $fatal(1, "bad byte at %0d", i);
      own_count++;
    end
  endfunction
endclass

module main;
  c_t o = new;
  int count, k1 = 1;
  initial begin
    foreach (o.name[k]) begin
      if (k != count) $fatal(1, "bad string index %0d at iteration %0d", k, count);
      count++;
    end
    if (count != 5) $fatal(1, "expected five iterations, got %0d", count);
    if (o.own_count() != 5) $fatal(1, "method foreach count %0d", o.own_count());
    if (o.depth() != 3) $fatal(1, "depth %0d", o.depth());
    if (!(o.name[k1] == ".")) $fatal(1, "external byte compare");
    o.name = "";
    foreach (o.name[k]) count++;
    if (count != 5) $fatal(1, "empty string iterated");
    if (o.own_count() != 0) $fatal(1, "empty method foreach iterated");
    if (o.depth() != 0) $fatal(1, "empty depth");
    $display("PASSED");
  end
endmodule
