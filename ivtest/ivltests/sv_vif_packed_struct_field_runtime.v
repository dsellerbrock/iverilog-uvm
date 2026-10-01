interface flash_packed_field_if;
  typedef struct packed {
    logic [7:0] addr;
    logic part;
    logic [1:0] info_sel;
  } entry_t;
  entry_t [1:0][1:0] rd_buf;
endinterface

class flash_packed_field_cfg;
  virtual flash_packed_field_if vif;
endclass

module top;
  flash_packed_field_if fi();
  flash_packed_field_cfg cfg;
  logic [1:0] unknown_index;
  int outer_oob, inner_oob, inner_below;

  initial begin
    cfg = new;
    cfg.vif = fi;
    fi.rd_buf[0][0] = {8'h11, 1'b0, 2'b00};
    fi.rd_buf[0][1] = {8'h22, 1'b1, 2'b01};
    fi.rd_buf[1][0] = {8'h33, 1'b0, 2'b10};
    fi.rd_buf[1][1] = {8'h44, 1'b1, 2'b11};

    for (int i = 0; i < 2; i++) begin
      for (int j = 0; j < 2; j++) begin
        if (cfg.vif.rd_buf[i][j].addr !== fi.rd_buf[i][j].addr
            || cfg.vif.rd_buf[i][j].part !== fi.rd_buf[i][j].part
            || cfg.vif.rd_buf[i][j].info_sel !== fi.rd_buf[i][j].info_sel)
          $fatal(1, "wrong VIF slot or field [%0d][%0d]", i, j);
      end
    end

    outer_oob = 2;
    inner_oob = 2;
    inner_below = -1;
    unknown_index = 'x;
    if (cfg.vif.rd_buf[outer_oob][0].addr !== 8'hxx
        || cfg.vif.rd_buf[0][inner_oob].addr !== 8'hxx
        || cfg.vif.rd_buf[1][inner_below].addr !== 8'hxx
        || cfg.vif.rd_buf[unknown_index][0].addr !== 8'hxx
        || cfg.vif.rd_buf[0][unknown_index].addr !== 8'hxx)
      $fatal(1, "VIF invalid index aliased a slot");
    if (fi.rd_buf[outer_oob][0].addr !== 8'hxx
        || fi.rd_buf[unknown_index][0].addr !== 8'hxx
        || fi.rd_buf[0][unknown_index].addr !== 8'hxx)
      $fatal(1, "physical invalid index aliased a slot");
    $display("PASSED");
  end
endmodule
