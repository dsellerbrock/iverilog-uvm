// M4C-10: `automatic event e;` and `static event e;` as a block_item_decl
// (a leading declaration in a `begin ... end` body, a task body, or a
// fork branch) were a bare syntax error; plain `event e;` in the same
// position already worked.
//
// IEEE 1800-2017 6.17 (event data type) and 6.21 (scope and lifetime):
// a named event is a synchronization identity, and `static`/`automatic`
// on any block-local declaration says how many *instances* of that
// identity exist across activations of the enclosing scope.
//
//   - `static event e;` is just an explicit spelling of the (module-
//     inherited) default: one event instance for the life of the
//     simulation, shared by every activation. This must trigger/wait
//     exactly like plain `event e;`.
//   - `automatic event e;` asks for a *fresh* synchronization identity
//     on every activation of the enclosing scope. Icarus elaborates a
//     named event exactly once per lexical scope instance -- a single
//     compile-time NetEvent/vvp event functor tied to the PEvent pform
//     node (see PEvent::elaborate_scope), not to a per-call storage
//     frame -- so it cannot honor a fresh identity per activation. This
//     is a loud, tracked "sorry" rather than a silent degrade; it is
//     exercised as a compile-time negative test in
//     tests/negative/event_automatic_lifetime.sv, not here.
//
// This test pins the three outcomes that must still work: `static`
// event lifetime, unchanged plain `event`, and an unchanged
// module-scope named event -- each independently trigger/wait checked
// without `fork`/`join_none` racing the pass/fail counter.

module main;
  int fails = 0;
  event mod_e;   // module-scope event: grammar for module-scope event
                 // declarations was not touched by the M4C-10 fix.

  task automatic check_static;
    static event e;   // explicit spelling of the default lifetime
    int n;
    n = 0;
    fork
      begin
        @e n = 1;
      end
    join_none
    #1 ->e;
    #1;
    if (n != 1) begin
      $display("FAILED: static event trigger/wait, n=%0d", n);
      fails = fails + 1;
    end
  endtask

  task automatic check_plain;
    event e;          // unchanged: default (inherited/static) lifetime
    int n;
    n = 0;
    fork
      begin
        @e n = 1;
      end
    join_none
    #1 ->e;
    #1;
    if (n != 1) begin
      $display("FAILED: plain event trigger/wait, n=%0d", n);
      fails = fails + 1;
    end
  endtask

  task automatic check_module_scope;
    int n;
    n = 0;
    fork
      begin
        @mod_e n = 1;
      end
    join_none
    #1 ->mod_e;
    #1;
    if (n != 1) begin
      $display("FAILED: module-scope event trigger/wait, n=%0d", n);
      fails = fails + 1;
    end
  endtask

  initial begin
    check_static();
    check_plain();
    check_module_scope();
    if (fails == 0) $display("PASSED");
    $finish(0);
  end
endmodule
