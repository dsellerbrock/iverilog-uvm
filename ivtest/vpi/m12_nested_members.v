// M12-5: nested class-member traversal via VPI — dotted-path
// handle_by_name through object-valued members at any depth,
// vpiMember iteration recursion, handles staying live across
// re-assignment along the path, and graceful null intermediates.
module top;
  class Leaf;
    int count = 7;
    string tag = "leaf0";
  endclass
  class Cfg;
    Leaf leaf;
    function new; leaf = new; endfunction
  endclass
  class Agent;
    Cfg cfg;
    int id = 3;
    function new; cfg = new; endfunction
  endclass
  class Env;
    Agent agent;
    Agent dead;               // stays null
    function new; agent = new; endfunction
  endclass
  Env env;
  initial begin
    env = new;
    $m12nm_probe;             // reads 7, writes 42; deep tag -> 'vpi'
    // swap the whole agent subtree: the SAME deep handle must now
    // reach the fresh objects
    env.agent = new;
    env.agent.cfg.leaf.count = 100;
    $m12nm_reprobe;           // reads 100, writes 55
    #1 $display("final: count=%0d tag='%s' id=%0d",
                env.agent.cfg.leaf.count, env.agent.cfg.leaf.tag,
                env.agent.id);
    $finish(0);
  end
endmodule
