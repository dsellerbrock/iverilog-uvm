package packed_parameter_scalar_pkg;
  parameter bit STATUS = 1'b1;
  parameter int COUNT = 7;
  class model;
    task run();
      foreach (STATUS[i]) $fatal(1, "scalar foreach body ran");
      foreach (COUNT[j]) $fatal(1, "atom foreach body ran");
    endtask
  endclass
endpackage

module main;
  packed_parameter_scalar_pkg::model obj;
  initial begin
    obj = new;
    obj.run();
  end
endmodule
