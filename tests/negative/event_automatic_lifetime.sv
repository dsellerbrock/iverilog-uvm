// M4C-10 / IEEE 1800-2017 6.17, 6.21: `automatic event e;` asks for a
// fresh synchronization identity on every activation of the enclosing
// scope. Icarus elaborates a named event exactly once per lexical scope
// instance (a single compile-time event functor -- see
// PEvent::elaborate_scope), with no per-activation storage, so it cannot
// honor that. This must be a loud, diagnosed rejection ("sorry"), not a
// silent degrade to static behavior and not a bare syntax error.
module event_automatic_lifetime;
  initial begin
    automatic event e;
    -> e;
  end
endmodule
