// T1 repro: class-method parameter becomes null after a 3-level call chain
// with #0 yield at deepest level, run inside fork+join_none.
//
// Trace evidence (IVL_LOAD_STR_TRACE=c IVL_CTX_TRACE=process_phase):
//   alloc 0xd280 for process_phase  (frame A1)
//   ... sync_phase frame allocated (frame B at 0xc850 — REUSED address)
//   join-pop-push relabels 0xc850 from process_phase to sync_phase scope
//   on return: rd_scoped scope=process_phase source=miss
//
// Root cause: context allocator returns the same memory pointer (0xc850) to
// two different scopes; line 2835 overwrites automatic_context_owner[ctx]
// from process_phase to sync_phase.  Caller's wt_head check then fails
// because owner != ctx_scope, so the param read returns null.
//
// Bug requires all four:
//   (a) class methods (not free tasks)
//   (b) 3+ level call chain
//   (c) yield via #0 at deepest level
//   (d) fork+join_none somewhere upstream
//
// Symptom: UVM phase orchestration silently no-ops past sync_phase.

class container;
  string name;
  function new(string n); name=n; endfunction
endclass

class outer;
  task wait_eq(); #0; endtask

  task sync_phase(container c);
    $display("[sync] enter null?%0d c='%s'", c==null, c==null ? "" : c.name);
    wait_eq();
    $display("[sync] after #0 null?%0d c='%s'", c==null, c==null ? "" : c.name);
  endtask

  task process_phase(container c);
    $display("[proc] enter null?%0d c='%s'", c==null, c.name);
    sync_phase(c);
    $display("[proc] after sync null?%0d c='%s' %s", c==null, c==null ? "" : c.name,
             c == null ? "FAIL" : "PASS");
  endtask
endclass

module top;
  outer o;
  container ph;
  initial begin
    o = new();
    ph = new("common");
    fork
      begin
        fork
          begin
            o.process_phase(ph);
          end
        join_none
      end
    join_none
    #100;
    $finish;
  end
endmodule
