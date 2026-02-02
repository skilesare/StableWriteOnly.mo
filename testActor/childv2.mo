import D "mo:core/Debug";
import List "mo:core/List";
import Nat "mo:core/Nat";
import SW "../src/";



shared(init_msg) persistent actor class Child2() = this {

  public type TestType1 = {
    one: Nat;
    two: Text;
    three: Nat64;
  };

  stable var testVar = 1;
  stable var testVar2 = 3;

  stable var memStore = SW.init({
    maxPages = 64;
    indexType = #Managed;
  });

  transient let mem = SW.StableWriteOnly(?memStore);

  public query func stats() : async SW.Stats{
    mem.stats();
  };

  public query func read(x : Nat) : async ?TestType1 {
    let ?blob = mem.read(x) else return null;
    return (from_candid(blob) : ?TestType1);
  };

  public shared func putData(x : TestType1) : async SW.WriteResult {
    return mem.write(to_candid(x));
  };

  transient var dataBlock : ?List.List<TestType1> = null;

  // Batch size to avoid exceeding instruction limit per message
  let BATCH_SIZE = 50_000;

  public shared func putLotsOfData(x : Nat) : async SW.Stats {
    // Process in batches to avoid exceeding instruction limit
    await putLotsOfDataBatch(x, 0);
  };

  private func putLotsOfDataBatch(total : Nat, startFrom : Nat) : async SW.Stats {
    // Write directly to stable memory without caching in Wasm heap
    var tracker = startFrom;
    let batchEnd = Nat.min(startFrom + BATCH_SIZE, total);
    
    label proc loop{
      let item : TestType1 = {
        one = tracker : Nat;
        two = "test";
        three = 15;
      };
      let result = mem.write(to_candid(item));
      switch(result){
        case(#err(#MemoryFull)){
          return mem.stats();
        };
        case(#err(#IndexFull)){
          return mem.stats();
        };
        case(_){};
      };
      
      tracker := tracker + 1;
      if(tracker >= batchEnd){break proc};
    };

    // If more to process, yield and continue with next batch
    if(tracker < total){
      return await putLotsOfDataBatch(total, tracker);
    };

    return mem.stats();
  };

  public type VecTypes = {
    #TestType1: TestType1;
    #TestType3: TestType3;
  };

   public type TestType3 = {
    five: {
      #six;
      #seven;
    };
  };

  public query func readTyped(x : Nat) : async ?VecTypes {
    //D.print("about to read block");
    let ?val = mem.readTyped(x) else return null;
    switch(val.1){
      case(null) return null;
      case(?type_of){
        if(type_of == 0){
          return ?#TestType1(
            switch(from_candid(val.0) : ?TestType1){
              case(null) return null;
              case(?v) v;
            });
        } else {
          return ?#TestType3(
            switch(from_candid(val.0) : ?TestType3){
              case(null) return null;
              case(?v) v;
            });
        };
      };
    };
  };
};