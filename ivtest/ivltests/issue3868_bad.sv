module issue3868_bad;
  typedef enum byte { A = 65 } byte_enum;

  int wider[];
  byte_enum enum_bytes[$];
  byte associative[int];
  byte bytes[];

  initial begin
    wider = "A";
    enum_bytes = "A";
    associative = "A";
    bytes = new[2]("A");
  end
endmodule
