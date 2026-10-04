`timescale 1ns/1ps
module top;
  typedef bit [31:0] addr_t;
  typedef bit [31:0] data_t;
  typedef data_t data_model_t[addr_t];

  data_model_t scb_flash_data;

  task automatic update_model;
    data_model_t local_model;
    for (int i = 0; i < 524288; i++)
      local_model[addr_t'(i)] = data_t'(i ^ 32'h5a5a5a5a);
    $display("INSERTED keys=%0d", local_model.num());
    scb_flash_data = local_model;
    $display("COPIED keys=%0d", scb_flash_data.num());
    for (int i = 0; i < 524288; i++)
      if (scb_flash_data[addr_t'(i)] !== data_t'(i ^ 32'h5a5a5a5a))
        $fatal(1, "lookup mismatch at %0d", i);
    $display("FLASH ASSOC BENCH PASS keys=%0d", scb_flash_data.num());
  endtask

  initial begin
    update_model();
    $finish;
  end
endmodule
