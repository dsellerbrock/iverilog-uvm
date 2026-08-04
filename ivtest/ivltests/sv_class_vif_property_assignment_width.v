// Integral assignment to a class or virtual-interface property must apply the
// destination's assignment width before %store/prop/v or %assign/prop/v pops
// the value.  In particular, a narrow unsigned RHS is zero-extended, a narrow
// signed RHS is sign-extended, and a wide RHS is truncated.  Exercise both
// blocking and nonblocking property stores (IEEE 1800-2017 10.4 and 11.8.3).

interface property_width_if;
  logic        [31:0] u;
  logic signed [31:0] s;
  logic         [9:0] n;
endinterface

// The OpenTitan failure uses a non-default virtual-interface specialization.
// Its expression is statically context-sized from the interface netclass, but
// the bound instance returns its actual parameterized width at run time.
interface parameterized_property_width_if #(parameter int W = 32);
  logic [W-1:0] src;
  logic [W-1:0] blocking_dst;
  logic [W-1:0] nba_dst;
endinterface

module sv_class_vif_property_assignment_width;
  class holder;
    logic        [31:0] u;
    logic signed [31:0] s;
    logic         [9:0] n;
  endclass

  property_width_if intf();
  parameterized_property_width_if #(.W(10)) param_intf();
  virtual property_width_if vif;
  virtual parameterized_property_width_if #(.W(10)) param_vif;
  holder obj;
  logic        [9:0] narrow_u;
  logic signed [9:0] narrow_s;
  logic       [31:0] wide;
  int errors = 0;

  task automatic check_class(string phase,
                             logic [31:0] want_u,
                             logic [31:0] want_s,
                             logic  [9:0] want_n);
    if (obj.u !== want_u) begin
      $display("FAILED class %s unsigned: got %h want %h", phase, obj.u, want_u);
      errors++;
    end
    if (obj.s !== want_s) begin
      $display("FAILED class %s signed: got %h want %h", phase, obj.s, want_s);
      errors++;
    end
    if (obj.n !== want_n) begin
      $display("FAILED class %s narrow: got %h want %h", phase, obj.n, want_n);
      errors++;
    end
  endtask

  task automatic check_vif(string phase,
                           logic [31:0] want_u,
                           logic [31:0] want_s,
                           logic  [9:0] want_n);
    if (vif.u !== want_u) begin
      $display("FAILED vif %s unsigned: got %h want %h", phase, vif.u, want_u);
      errors++;
    end
    if (vif.s !== want_s) begin
      $display("FAILED vif %s signed: got %h want %h", phase, vif.s, want_s);
      errors++;
    end
    if (vif.n !== want_n) begin
      $display("FAILED vif %s narrow: got %h want %h", phase, vif.n, want_n);
      errors++;
    end
  endtask

  initial begin
    obj = new;
    vif = intf;
    param_vif = param_intf;

    narrow_u = 10'h2a5;
    narrow_s = -10'sd3;
    wide = 32'hdead_beef;
    obj.u = narrow_u;
    obj.s = narrow_s;
    obj.n = wide;
    vif.u = narrow_u;
    vif.s = narrow_s;
    vif.n = wide;
    check_class("blocking", 32'h0000_02a5, 32'hffff_fffd, 10'h2ef);
    check_vif("blocking", 32'h0000_02a5, 32'hffff_fffd, 10'h2ef);

    param_intf.src = 10'h2d3;
    param_vif.blocking_dst = param_vif.src;
    if (param_intf.blocking_dst !== 10'h2d3) begin
      $display("FAILED specialized vif blocking: got %h want 2d3",
               param_intf.blocking_dst);
      errors++;
    end
    param_vif.nba_dst <= param_vif.src;

    narrow_u = 10'h155;
    narrow_s = -10'sd7;
    wide = 32'h1234_5678;
    obj.u <= narrow_u;
    obj.s <= narrow_s;
    obj.n <= wide;
    vif.u <= narrow_u;
    vif.s <= narrow_s;
    vif.n <= wide;
    #1;
    check_class("NBA", 32'h0000_0155, 32'hffff_fff9, 10'h278);
    check_vif("NBA", 32'h0000_0155, 32'hffff_fff9, 10'h278);
    if (param_intf.nba_dst !== 10'h2d3) begin
      $display("FAILED specialized vif NBA: got %h want 2d3", param_intf.nba_dst);
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
