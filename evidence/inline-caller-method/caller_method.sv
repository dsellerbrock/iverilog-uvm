// Inline randomize-with constraint calling a method of a caller-owned object
// (IEEE 1800-2017 18.5.12/18.7; 1800-2023 18.5.11/18.7).
class cfg_c;
  int mode;
  virtual function int get_size();
    case (mode)
      0: return 1;
      1: return 2;
      2: return 4;
      default: return 0;
    endcase
  endfunction
endclass

class cfg_d extends cfg_c;
  virtual function int get_size();
    return 3;
  endfunction
endclass

class cfg_e extends cfg_c;
  virtual function int get_size();
    return 8;
  endfunction
endclass

class item;
  rand bit [2:0] lanes;
endclass

class seq;
  cfg_c cfg;
  function int run(item it);
    return it.randomize() with { lanes == cfg.get_size(); };
  endfunction
endclass

module top;
  seq s;
  item it;
  int errs;
  initial begin
    s = new;
    it = new;
    s.cfg = new;
    for (int m = 0; m < 3; m++) begin
      s.cfg.mode = m;
      if (!s.run(it) || it.lanes != (1 << m)) begin
        $display("FAIL mode=%0d ok lanes=%0d", m, it.lanes); errs++;
      end
    end
    // Virtual dispatch through the caller's handle.
    begin cfg_d d; d = new; s.cfg = d; end
    if (!s.run(it) || it.lanes != 3) begin $display("FAIL virtual lanes=%0d", it.lanes); errs++; end
    s.cfg = new; s.cfg.mode = 7; // get_size() == 0
    if (!s.run(it) || it.lanes != 0) begin $display("FAIL zero lanes=%0d", it.lanes); errs++; end
    // Unsatisfiable: 8 does not fit in 3 bits; randomize fails, value kept.
    s.cfg.mode = 2; void'(s.run(it));
    begin cfg_e e; e = new; s.cfg = e; end
    if (s.run(it) != 0 || it.lanes != 4) begin $display("FAIL unsat lanes=%0d", it.lanes); errs++; end
    if (errs == 0) $display("PASSED");
  end
endmodule
