// Constraint values wider than 64 bits and associative-array foreach keys.
// IEEE 1800-2017 18.5.4 / 1800-2023 18.5.3 (dist), 18.4 (random storage),
// and 12.7.3 (an associative-array foreach binds its loop variable to keys).
typedef struct { rand logic [127:0] k; rand logic [127:0] ks [2]; } key_rec_t;

package wide_dist_pkg;
  localparam bit [127:0] BIG = 128'h0000000000000001_0000000000000000;
endpackage

// A 64-bit subject cannot equal a value with bits above 63, so these dist
// constraints have no feasible item and randomize() must fail.
class dist_out_of_range_literal;
  rand bit [63:0] value;
  constraint c { value dist {128'h0000000000000001_0000000000000000 := 1}; }
endclass

class dist_out_of_range_parameter;
  rand bit [63:0] value;
  constraint c { value dist {wide_dist_pkg::BIG :/ 1}; }
endclass

class dist_wide_storage;
  rand bit [127:0] value;
  constraint c { value dist {128'd1 :/ 1}; }
endclass

class dist_state_cfg;
  bit [127:0] endpoint = 128'd1;
endclass

class dist_wide_nested_state;
  rand bit value;
  dist_state_cfg cfg = new;
  constraint c { value dist {cfg.endpoint :/ 1, 0 :/ 1}; }
endclass

class wide_dist;
  localparam logic [127:0] K1 = {64'hDEAD_BEEF_0000_0001, 64'h5};
  localparam logic [127:0] K2 = {64'hCAFE_F00D_0000_0002, 64'h7};
  localparam logic [127:0] LO = {64'h0000_0001_0000_0000, 64'h0};
  localparam logic [127:0] HI = {64'h0000_0001_0000_0000, 64'hF};
  localparam logic signed [99:0] SLO = -3, SHI = 2;
  rand logic [127:0] s, r, c;
  rand logic signed [99:0] sg;
  constraint c_s  { s dist { K1 := 1, K2 := 3 }; }
  constraint c_r  { r dist { [LO:HI] :/ 1 }; }
  constraint c_c  { c dist { K1 := 1, K2 := 1 }; c != K2; }
  constraint c_sg { sg dist { [SLO:SHI] := 1 }; }
endclass

class sparse_dist;
  localparam logic [127:0] A = {56'h0, 72'h12_0000_0000_0000_0001};
  localparam logic [127:0] B = {56'h0, 72'h34_0000_0000_0000_0002};
  rand logic [127:0] r;
  constraint c_r { r dist { [0 : {56'h0, 72'hFF_FFFF_FFFF_FFFF_FFFF}] :/ 1 };
                   r inside {A, B}; }
endclass

class wide_storage;
  localparam logic [127:0] K1 = {64'hDEAD_BEEF_0000_0001, 64'h5};
  rand logic [127:0] arr [3];
  rand logic [127:0] dq [];
  rand logic [127:0] q [$];
  rand key_rec_t rec;
  constraint c { foreach (arr[i]) arr[i] == K1 + i;
                 dq.size() == 2; foreach (dq[i]) dq[i] == K1 - i;
                 q.size() == 2; foreach (q[i]) q[i] == K1 + 10 + i;
                 rec.k == K1; foreach (rec.ks[i]) rec.ks[i] == K1 + 20 + i; }
endclass

class assoc_keys;
  localparam logic [127:0] K1 = {64'hDEAD_BEEF_0000_0001, 64'h5};
  rand logic [31:0]  n   [int];
  rand logic [127:0] w   [int];
  rand logic [15:0]  u8  [bit [7:0]];
  rand logic [15:0]  neg [int];
  rand logic [15:0]  wk  [bit [99:0]];
  rand logic [15:0]  direct [int];
  function new();
    n[3] = 0; n[7] = 0; w[3] = 0; w[7] = 0;
    u8[8'd200] = 0; u8[8'd5] = 0;
    neg[-4] = 0; neg[9] = 0;
    wk[{36'h9_0000_0000, 64'h1}] = 0; wk[100'd2] = 0;
    direct[10] = 0; direct[20] = 0;
  endfunction
  constraint c1 { foreach (n[i]) n[i] == 32'h1000 + i; }
  constraint c2 { foreach (w[i]) w[i] == K1 + i; }
  constraint c3 { foreach (u8[k]) u8[k] == 16'(k); }
  constraint c4 { foreach (neg[k]) neg[k] == 16'(k + 100); }
  constraint c5 { foreach (wk[k]) wk[k] == 16'(k[99:96]) + 16'(k[3:0]); }
  constraint c6 { direct[20] == 16'h2020; direct[10] == 16'h1010; }
endclass

class key_obj;
  int id;
  function new(int i); id = i; endfunction
endclass

class entry_keys;
  rand logic [15:0] ca [key_obj];
  rand logic [15:0] sa [string];
  key_obj k1, k2;
  function new();
    k1 = new(3); k2 = new(7);
    ca[k1] = 0; ca[k2] = 0;
    sa["alpha"] = 0; sa["beta"] = 0;
  endfunction
  constraint c_class { foreach (ca[k]) ca[k] == 16'(k.id) + 16'h100; }
  constraint c_str   { foreach (sa[s]) sa[s] inside {[16'h10:16'h20]}; }
  constraint c_sdir  { sa["beta"] == 16'h15; }
endclass

// A string-key foreach body may use dist on the visited element
// (OpenTitan dv_base_env_cfg.sv:62, DV_COMMON_CLK_CONSTRAINT).
class string_key_dist;
  rand int unsigned freqs [string];
  function new(); freqs["a"] = 0; freqs["b"] = 0; endfunction
  constraint c { foreach (freqs[i]) { freqs[i] dist { [5:23] :/ 2, 96 :/ 1 }; } }
endclass

// inside over a fixed caller-scope array denotes its elements (11.4.13),
// at their full width (OpenTitan lc_ctrl_errors_vseq.sv:548).
class token_picker;
  function automatic bit pick(output logic [127:0] out, input bit member);
    logic [127:0] tokens_a [3];
    logic [127:0] token;
    tokens_a[0] = {64'hDEAD_BEEF_0000_0001, 64'h5};
    tokens_a[1] = {64'hCAFE_F00D_0000_0002, 64'h7};
    tokens_a[2] = 128'h9;
    if (member) begin
      if (!std::randomize(token) with { token inside {tokens_a}; }) return 0;
    end else begin
      if (!std::randomize(token) with { !(token inside {tokens_a}); }) return 0;
    end
    out = token;
    return member == (token inside {tokens_a});
  endfunction
endclass

class missing_string_key;
  rand logic [15:0] sa [string];
  function new(); sa["a"] = 0; endfunction
  constraint c { sa["zzz"] == 16'h5; }
endclass

class missing_key;
  rand logic [15:0] a [int];
  function new(); a[10] = 0; endfunction
  constraint c { a[99] == 16'h1; }
endclass

module test;
  wide_dist wd = new;
  sparse_dist sp = new;
  wide_storage ws = new;
  assoc_keys ak = new;
  missing_key mk = new;
  string_key_dist skd = new;
  token_picker tp = new;
  logic [127:0] picked;
  int in_lo = 0, in_hi = 0, tok0 = 0;
  dist_out_of_range_literal oor_lit = new;
  dist_out_of_range_parameter oor_par = new;
  dist_wide_storage dws = new;
  dist_wide_nested_state dns = new;
  bit scope_value;
  bit [127:0] caller_wide = 128'h0000000000000001_0000000000000000;
  int ones = 0, zeros = 0;
  entry_keys ek = new;
  missing_string_key msk = new;
  logic [127:0] x;
  int k1 = 0, k2 = 0, neg = 0, pos = 0, a = 0, b = 0;
  int hits [16];
  bit failed = 0;

  task automatic check(string what, bit ok);
    if (!ok) begin
      $display("FAILED %s", what);
      failed = 1;
    end
  endtask

  initial begin
    repeat (400) begin
      check("dist randomize", wd.randomize());
      if (wd.s === wide_dist::K1) k1++;
      else if (wd.s === wide_dist::K2) k2++;
      else check("dist scalar item", 0);
      check("dist range", wd.r >= wide_dist::LO && wd.r <= wide_dist::HI);
      hits[wd.r[3:0]]++;
      check("dist with constraint", wd.c === wide_dist::K1);
      check("signed dist range", wd.sg >= -3 && wd.sg <= 2);
      if (wd.sg < 0) neg++; else pos++;
    end
    check("dist weights", k2 > 2 * k1 && k1 > 50);
    check("signed dist spread", neg > 100 && pos > 100);
    foreach (hits[i]) check("dist range spread", hits[i] > 0);
    repeat (50) check("std::randomize dist",
      std::randomize(x) with { x dist { wide_dist::K1 := 1, wide_dist::K2 := 1 }; }
      && (x === wide_dist::K1 || x === wide_dist::K2));
    repeat (100) begin
      check("sparse dist randomize", sp.randomize());
      if (sp.r === sparse_dist::A) a++;
      else if (sp.r === sparse_dist::B) b++;
      else check("sparse dist member", 0);
    end
    check("sparse dist spread", a > 20 && b > 20);
    check("dist item beyond 64-bit subject fails", !oor_lit.randomize());
    check("dist parameter beyond 64-bit subject fails", !oor_par.randomize());
    check("wide dist storage", dws.randomize() && dws.value === 128'd1);
    repeat (100) begin
      check("wide nested state dist", dns.randomize());
      if (dns.value) ones++; else zeros++;
    end
    check("wide nested state dist spread", ones > 20 && zeros > 20);
    repeat (20) check("wide caller value dist",
      std::randomize(scope_value) with { scope_value dist {caller_wide :/ 1, 0 :/ 1}; }
      && scope_value == 0);

    check("storage randomize", ws.randomize());
    check("fixed array element", ws.arr[2] === wide_storage::K1 + 2);
    check("dynamic array element", ws.dq[1] === wide_storage::K1 - 1);
    check("queue element", ws.q[1] === wide_storage::K1 + 11);
    check("struct member", ws.rec.k === wide_storage::K1);
    check("struct member array", ws.rec.ks[1] === wide_storage::K1 + 21);

    check("assoc randomize", ak.randomize());
    check("assoc int keys", ak.n[3] === 32'h1003 && ak.n[7] === 32'h1007);
    check("assoc wide element", ak.w[7] === assoc_keys::K1 + 7);
    check("assoc unsigned key", ak.u8[8'd200] === 16'd200 && ak.u8[8'd5] === 16'd5);
    check("assoc negative key", ak.neg[-4] === 16'd96 && ak.neg[9] === 16'd109);
    check("assoc wide key", ak.wk[{36'h9_0000_0000, 64'h1}] === 16'd10
          && ak.wk[100'd2] === 16'd2);
    check("assoc constant key", ak.direct[10] === 16'h1010 && ak.direct[20] === 16'h2020);
    check("assoc missing key fails", !mk.randomize());
    check("entry-key randomize", ek.randomize());
    check("class key foreach", ek.ca[ek.k1] === 16'h103 && ek.ca[ek.k2] === 16'h107);
    check("string key foreach", ek.sa["alpha"] >= 16'h10 && ek.sa["alpha"] <= 16'h20);
    check("constant string key", ek.sa["beta"] === 16'h15);
    check("missing string key fails", !msk.randomize());
    repeat (100) begin
      check("string-key dist randomize", skd.randomize());
      foreach (skd.freqs[k]) begin
        if (skd.freqs[k] inside {[5:23]}) in_lo++;
        else if (skd.freqs[k] == 96) in_hi++;
        else check("string-key dist member", 0);
      end
    end
    check("string-key dist spread", in_lo > in_hi && in_hi > 20);
    repeat (40) begin
      check("inside fixed caller array", tp.pick(picked, 1));
      if (picked === {64'hDEAD_BEEF_0000_0001, 64'h5}) tok0++;
    end
    check("inside fixed caller array spread", tok0 > 3);
    repeat (40) check("not inside fixed caller array", tp.pick(picked, 0));
    if (!failed) $display("PASSED");
  end
endmodule
