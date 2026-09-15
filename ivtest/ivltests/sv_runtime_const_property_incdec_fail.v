module test;
  class C;
    const int scalar=5;
    const int values[2]='{5,7};
  endclass
  C c;
  int result;
  initial begin
    c=new;
    result=c.scalar++;
    result=--c.values[0];
  end
endmodule
