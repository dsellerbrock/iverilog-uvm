// A run-time indexed range after a packed element index selects inside that
// element's own dimension: bits beyond the dimension read X instead of
// aliasing the neighboring element (IEEE 1800-2017/2023 11.5.1, 7.4.3).
// Covers a class property and a packed struct member of a virtual interface
// (OpenTitan flash_ctrl keymgr.seeds[sel][i*32+:32]).
typedef struct packed { logic [1:0][63:0] seeds; } kf_t;

interface fif;
  kf_t keymgr;
endinterface

class holder;
  virtual fif vif;
  logic [1:0][63:0] local_seeds;
  logic [1:0] sel;

  function logic [31:0] up(int i);
    return local_seeds[sel[0]][i*32 +: 32];
  endfunction
  function logic [31:0] down(int i);
    return local_seeds[sel[0]][i*32 + 31 -: 32];
  endfunction
  function logic [31:0] via_vif(int i);
    return vif.keymgr.seeds[sel[0]][i*32 +: 32];
  endfunction
endclass

module main;
  int errors;
  fif f();
  holder h;

  task automatic check(string what, logic [31:0] got, logic [31:0] want);
    if (got !== want) begin
      $display("FAILED %s: got %h want %h", what, got, want);
      errors++;
    end
  endtask

  initial begin
    h = new;
    f.keymgr.seeds = 128'h0123456789abcdef_fedcba9876543210;
    h.vif = f;
    h.local_seeds = f.keymgr.seeds;
    h.sel = 1;
    check("up 0", h.up(0), 32'h89abcdef);
    check("up 1", h.up(1), 32'h01234567);
    check("up 2 out of range", h.up(2), 32'hxxxxxxxx);
    check("up -1 out of range", h.up(-1), 32'hxxxxxxxx);
    check("down 0", h.down(0), 32'h89abcdef);
    check("down 1", h.down(1), 32'h01234567);
    check("vif 0", h.via_vif(0), 32'h89abcdef);
    check("vif 1", h.via_vif(1), 32'h01234567);
    check("vif 2 out of range", h.via_vif(2), 32'hxxxxxxxx);
    h.sel = 0;
    check("low row 0", h.up(0), 32'h76543210);
    check("low row 1", h.up(1), 32'hfedcba98);
    check("vif low row 1", h.via_vif(1), 32'hfedcba98);
    if (errors == 0) $display("PASSED");
  end
endmodule
