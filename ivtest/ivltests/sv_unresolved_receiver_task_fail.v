class empty_class;
  int scalar;
endclass
module child;
endmodule
module test;
  empty_class obj, m;
  child dut();
  initial begin
    missing_receiver.run();
    missing_receiver[0].run();
    dut.missing.run();
    obj.missing.run();
    absent[0].clear();
    absent.copy();
    absent.reset();
    absent[0].get_fields();
    absent.constraint_mode(0);
    absent.c.constraint_mode(0);
    atomic.put(1);
    obj.mirror();
    m.write(1);
    obj.no_constraint.constraint_mode(0);
    obj.scalar.delete();
    obj.scalar.push_back(1);
    obj.scalar.push_front(1);
    obj.scalar.insert(0, 1);
  end
endmodule
