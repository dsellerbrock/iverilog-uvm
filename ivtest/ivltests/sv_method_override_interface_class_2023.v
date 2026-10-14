interface class method_override_parent_api;
  pure virtual function int value();
endclass

interface class method_override_api extends method_override_parent_api;
  pure virtual function :initial int value();
endclass

module test;
endmodule
