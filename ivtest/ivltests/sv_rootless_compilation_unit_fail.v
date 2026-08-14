interface class required_api;
  pure virtual function int required_value();
endclass

class incomplete implements required_api;
endclass
