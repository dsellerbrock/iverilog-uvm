// IEEE 1800-2017/2023 13.5: copy an output class handle through an
// associative class property with a fixed-array child.
typedef enum bit [1:0] {Data, Info} part_e;

class copyout_base;
  int unsigned size_bytes;
  function new(int unsigned size_bytes);
    this.size_bytes = size_bytes;
  endfunction
  virtual function int unsigned read_size();
    return size_bytes;
  endfunction
endclass

class copyout_derived extends copyout_base;
  function new(int unsigned size_bytes);
    super.new(size_bytes);
  endfunction
endclass

class copyout_cfg;
  copyout_base direct;
  copyout_base fixed[2];
  copyout_base mem[part_e][2];
endclass

module sv_function_copyout_assoc_fixed_class;
  copyout_cfg cfg;
  copyout_base resource;
  int index_calls;
  integer selected_bank;

  function automatic integer bank();
    index_calls++;
    return selected_bank;
  endfunction

  function automatic bit get(output copyout_base value);
    value = resource;
    return 1;
  endfunction

  initial begin
    copyout_derived constructed;
    copyout_base saved;
    part_e selected_part;
    cfg = new;
    constructed = new('h5000);
    resource = constructed;
    selected_part = Info;
    selected_bank = 0;

    if (!get(cfg.direct) || cfg.direct != resource)
      $fatal(1, "direct handle copy-out");
    if (!get(cfg.fixed[1]) || cfg.fixed[1] != resource
        || cfg.fixed[0] != null)
      $fatal(1, "fixed child copy-out");

    if (!get(cfg.mem[selected_part][bank()])) $fatal(1, "get return");
    if (index_calls != 1 || !cfg.mem.exists(Info)
        || cfg.mem[Info][0] != resource
        || cfg.mem[Info][0].read_size() != 'h5000)
      $fatal(1, "output handle or inherited state");
    saved = cfg.mem[Info][0];

    selected_part = Data;
    selected_bank = 'x;
    if (!get(cfg.mem[selected_part][bank()])) $fatal(1, "X index return");
    if (cfg.mem.exists(Data) || cfg.mem[Info][0] != saved
        || index_calls != 2)
      $fatal(1, "X index changed associative storage");

    selected_bank = 2;
    if (!get(cfg.mem[selected_part][bank()])) $fatal(1, "OOB return");
    if (cfg.mem.exists(Data) || cfg.mem[Info][0] != saved
        || index_calls != 3)
      $fatal(1, "OOB index changed associative storage");

    cfg = null;
    selected_bank = 0;
    if (!get(cfg.mem[selected_part][bank()])) $fatal(1, "null return");
    if (saved.read_size() != 'h5000) $fatal(1, "null receiver alias");
    $display("PASSED");
  end
endmodule
