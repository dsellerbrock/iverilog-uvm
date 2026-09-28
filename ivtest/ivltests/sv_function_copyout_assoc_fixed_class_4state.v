// IEEE 1800-2017/2023 7.8.6: an X/Z associative index must not
// materialize a fixed child during function output copy-out.
typedef enum logic [1:0] {Data = 2'b00, Info = 2'b01} part4_e;
typedef logic [63:0] wide_key_t;

class copyout_four_state_token;
  int value;
endclass

class copyout_four_state_cfg;
  copyout_four_state_token mem[part4_e][2];
  copyout_four_state_token wide_mem[wide_key_t][2];
endclass

module sv_function_copyout_assoc_fixed_class_4state;
  copyout_four_state_cfg cfg;
  copyout_four_state_token resource;
  part4_e requested_part;
  wide_key_t wide_key;
  int key_reads;

  function automatic part4_e selected_part();
    key_reads++;
    return requested_part;
  endfunction

  function automatic bit get(output copyout_four_state_token value);
    value = resource;
    return 1;
  endfunction

  initial begin
    cfg = new;
    resource = new;
    resource.value = 42;
    requested_part = Info;
    if (!get(cfg.mem[selected_part()][1])) $fatal(1, "known key return");
    if (key_reads != 1 || cfg.mem.num() != 1 || cfg.mem[Info][1] != resource)
      $fatal(1, "known four-state key copy-out");
    requested_part = part4_e'('x);
    if (!get(cfg.mem[selected_part()][0])) $fatal(1, "X key return");
    if (key_reads != 2 || cfg.mem.num() != 1 || cfg.mem[Info][1] != resource)
      $fatal(1, "X key created entry");
    requested_part = part4_e'('z);
    if (!get(cfg.mem[selected_part()][1])) $fatal(1, "Z key return");
    if (key_reads != 3 || cfg.mem.num() != 1 || cfg.mem[Info][1] != resource)
      $fatal(1, "Z key created entry");
    wide_key = 64'h4000_0000_0000_0001;
    if (!get(cfg.wide_mem[wide_key][1])) $fatal(1, "wide known key return");
    if (cfg.wide_mem.num() != 1 || cfg.wide_mem[wide_key][1] != resource)
      $fatal(1, "wide known key copy-out");
    wide_key[63] = 1'bx;
    if (!get(cfg.wide_mem[wide_key][0])) $fatal(1, "wide X key return");
    if (cfg.wide_mem.num() != 1)
      $fatal(1, "high X bit created entry");
    $display("PASSED");
  end
endmodule
