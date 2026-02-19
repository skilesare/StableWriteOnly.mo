import D "mo:core/Debug";
import List "mo:core/List";
import Nat "mo:core/Nat";
import Nat64 "mo:core/Nat64";
import Prim "mo:⛔";
import SW "../src/";

shared(init_msg) persistent actor class Child1(_args : ?SW.IndexType) = this {

  transient var args = _args;

  public type TestType1 = {
    one: Nat;
    two: Text;
    three: Nat64;
  };

  public type TestType3 = {
    five: {
      #six;
      #seven;
    };
  };

  public type VecTypes = {
    #TestType1: TestType1;
    #TestType3: TestType3;
  };

  stable var testVar = 1;

  stable var memStore = SW.init({
    maxPages = 64;
    indexType = switch(args){
      case(null){ #Managed;};
      case(?val){val};
    };
  });

  transient let mem = SW.StableWriteOnly(?memStore);

  public query func stats() : async SW.Stats{
    mem.stats();
  };

  public query func read(x : Nat) : async ?TestType1 {
    D.print("about to read block" # debug_show(x, mem.read(x)));
    let ?blob = mem.read(x) else return null;
    let val = from_candid(blob) : ?TestType1;
    D.print(" block " # debug_show(val));
    return val;
  };

  public query func test_candid() : async Bool {
    let myitem : TestType1 = {
      one = 1 : Nat;
      two = "test";
      three = 15;
    };

    let myBlob = to_candid(myitem);

    let myItem2 = (from_candid(myBlob) : ? TestType1);

    switch(myItem2){
      case(null) return false;
      case(?val) return (myitem.one == val.one and myitem.two == val.two);
    };
  };

  public shared func putData(x : TestType1) : async SW.WriteResult {
    return mem.write(to_candid(x));
  };

  transient var dataBlock : ?List.List<TestType1> = null;

  transient var dataBlock2: ?List.List<VecTypes> = null;

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
    
    if(tracker % 100000 == 0 or tracker == startFrom) D.print("processing data " # debug_show(tracker));
    
    label proc loop{
      let item : TestType1 = {
        one = tracker : Nat;
        two = "test";
        three = 15;
      };
      let result = mem.write(to_candid(item));
      switch(result){
        case(#err(#MemoryFull)){
          D.print("memory full at " # debug_show(tracker));
          return mem.stats();
        };
        case(#err(#IndexFull)){
          D.print("index full at " # debug_show(tracker));
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

  public query func readTyped(x : Nat) : async ?VecTypes {
    D.print("about to read block type");
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


  
  public shared func putLotsOfTypedData(x : Nat) : async SW.Stats {
    let data = switch(dataBlock2){
      case(null){
        let buf : List.List<VecTypes> = List.empty<VecTypes>();
        var tracker = 0;
        //D.print("about to write block");
        label proc loop{
          if(tracker % 100000 == 0) D.print("processing data " # debug_show(tracker));
          List.add<VecTypes>(buf, if(tracker % 2 == 0){
                #TestType1({
                one = tracker : Nat;
                two = "test";
                three = 15;
              } : TestType1)} else {
                #TestType3({
                five = #six;
              })
            }
          
          );
        
          if(tracker % 100000 == 0) D.print("data size " # debug_show(List.size(buf)));
          

          tracker := tracker + 1;
          if(tracker >= x){break proc};
          if(tracker % 100000 == 0) D.print("new tracker size " # debug_show(List.size(buf)));
        };
        dataBlock2 := ?buf;
        buf;

      };
      case(?val) val;
    };

    var write_tracker = 0;
    label write for(thisItem in List.values<VecTypes>(data)){
      if(write_tracker % 100000 ==0) D.print("writing data " # debug_show(write_tracker));

      switch(thisItem){
        case(#TestType1(val)){
          switch(mem.writeTyped(to_candid(val), 0)){
            case(#err(#MemoryFull)){
              break write;
            };
            case(_){};
          };
        };
        case(#TestType3(val)){
          switch(mem.writeTyped(to_candid(val), 1)){
            case(#err(#MemoryFull)){
              break write;
            };
            case(_){};
          };
        };
      };
      
      write_tracker := write_tracker + 1;
    };
    return mem.stats();
  };

  

  public shared func swapMemory() : async SW.Stats {
    let newMem = SW.init({maxPages = 32; indexType = switch(args){
      case(null){ #Managed;};
      case(?val){val};
    }});
    let sw = SW.StableWriteOnly(?newMem);

    let replaceItem = {
      one = 55;
      two = "test55";
      three = 55 : Nat64;
    };

    let result = sw.write(to_candid(replaceItem));

    return mem.swap(sw.toSwappable());
  };

  public shared func updateMaxPages(x : Nat64) : async SW.Stats {
    mem.updateMaxPages(x);
    return mem.stats();
  };

  /// Compare IC stable memory size with region-based calculation
  /// Returns: (icStableMemoryPages, regionBasedPages, dataPages, indexPages)
  public query func stableMemoryComparison() : async {
    icStableMemoryPages: Nat;
    regionBasedPages: Nat;
    dataPages: Nat;
    indexPages: Nat;
  } {
    let stats = mem.stats();
    let dataPages = Nat64.toNat(stats.currentPages);
    let indexPages = switch(stats.memory.pages) {
      case(?p) Nat64.toNat(p);
      case(null) 0;
    };
    let regionBasedPages = dataPages + indexPages;
    let icStableMemoryPages = Nat64.toNat(Prim.stableMemorySize());
    
    {
      icStableMemoryPages = icStableMemoryPages;
      regionBasedPages = regionBasedPages;
      dataPages = dataPages;
      indexPages = indexPages;
    };
  };
};