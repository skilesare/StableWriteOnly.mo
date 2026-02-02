import Array "mo:base/Array";
import D "mo:base/Debug";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import C "mo:matchers/Canister";
import M "mo:matchers/Matchers";
import S "mo:matchers/Suite";
import T "mo:matchers/Testable";

import Child1 "childv1";
import Child2 "childv2";


shared(init_msg) persistent actor class() = this {




public shared func test() : async {
        #success;
        #fail : Text;
    } {

        //let Instant_Test = await Instant.test_runner_instant_transfer();
        let suite = S.suite(
            "memory",
            [
              S.test("testUpgrade", switch(await testUpgrade()){case(#success){true};case(_){false};}, M.equals<Bool>(T.bool(true))),
              S.test("testSwap", switch(await testSwap()){case(#success){true};case(_){false};}, M.equals<Bool>(T.bool(true))),
              S.test("testStableIndex", switch(await testStableIndex()){case(#success){true};case(_){false};}, M.equals<Bool>(T.bool(true))),

              S.test("testStableTypedIndex", switch(await testStableTypedIndex()){case(#success){true};case(_){false};}, M.equals<Bool>(T.bool(true))),

              S.test("testStableMemoryComparison", switch(await testStableMemoryComparison()){case(#success){true};case(_){false};}, M.equals<Bool>(T.bool(true))),

              // Unfortunately the big data test stalls out in the local replica. Will need to be run in prod with a similiar schema to load in > 4GB of data.
              //S.test("testBigData", switch(await testBigData()){case(#success){true};case(_){false};}, M.equals<Bool>(T.bool(true))),

              
            ],
        );
        S.run(suite);

        return #success;
    };

    public shared func testUpgrade() : async { #success; #fail : Text } {
        
        //create a bucket canister
        D.print("testing Upgrade start");

        let childv1 = await Child1.Child1(null);

        D.print("have canister " # debug_show(Principal.fromActor(childv1)));

        //load it with data

        let dataResponse = await childv1.putLotsOfData(200000);

        D.print("data was put " # debug_show(dataResponse));

        //check that the memory endured
        //D.print("reading preResponse2 " # debug_show(dataResponse));
        let ?preResponse2 = await childv1.read(0) else D.trap("bad read preResponse2");
        //D.print("reading preResponse3 " # debug_show(dataResponse));
        let ?preResponse3 = await childv1.read(999) else D.trap("bad read preResponse3");

        D.print("data was " # debug_show(preResponse2, preResponse3));

        let preResponse4 = await childv1.putData({
          one = 55;
          two = "test55";
          three = 55 : Nat64;
        }) else D.trap("bad read preResponse4");


        //mem should be full, try to put one more object

        //upgrade it

        let childv2 = await (system Child2.Child2)(#upgrade childv1)();

        D.print("upgrade finished " # debug_show(Principal.fromActor(childv2)));


        //check that the memory endured
        let ?dataResponse2 = await childv1.read(0) else D.trap("bad read dataResponse2");
        let ?dataResponse3 = await childv1.read(999) else D.trap("bad read dataResponse3");
        D.print("data was " # debug_show(dataResponse2, dataResponse3));

        let finalStats = await childv1.stats() else D.trap("bad read finalStats");
        D.print("stats were " # debug_show(finalStats));


        //test responses

        let suite = S.suite(
            "test upgrade",
            [

                S.test(
                    "fail if stats don't match",
                    dataResponse.itemCount,
                    M.equals<Nat>(T.nat(105_270)), //max pages is 64 and this is the cutoff
                ), 
                S.test(
                    "fail if stats don't match",
                    dataResponse.currentPages,
                    M.equals<Nat64>(T.nat64(64)), //max pages is 64 and this is the cutoff
                ), 
                S.test(
                    "fail if can't read memory",
                    preResponse2.one,
                    M.equals<Nat>(T.nat(0)),
                ), 
                S.test(
                    "fail if can't read whole memeory",
                    preResponse3.one,
                    M.equals<Nat>(T.nat(999)),
                ), 
                S.test(
                    "fail if can't read memory after upgrade",
                    dataResponse2.one,
                    M.equals<Nat>(T.nat(0)),
                ), 
                 S.test(
                    "fail if can't read whole memory after upgrade",
                    dataResponse3.one,
                    M.equals<Nat>(T.nat(999)),
                ), 
                 S.test(
                    "fail if writing data doesn't return full memory",
                    switch(preResponse4){
                      case(#err(#MemoryFull)) "correct response";
                      case(_) "wrong response" # debug_show(preResponse4);
                    },
                    M.equals<Text>(T.text("correct response")),
                ), 
               

            ],
        );

        

        S.run(suite);

        return #success;
    };


    public shared func testStableIndex() : async { #success; #fail : Text } {
        
        //create a bucket canister
        D.print("testing StableIndex start");

        let childv1 = await Child1.Child1(?#Stable);

        D.print("have canister " # debug_show(Principal.fromActor(childv1)));

        //load it with data

        let dataResponse = await childv1.putLotsOfData(200000);

        D.print("data was put " # debug_show(dataResponse));

        //check that the memory endured
        //D.print("reading preResponse2 " # debug_show(dataResponse));
        let ?preResponse2 = await childv1.read(0) else D.trap("bad read preResponse2");
        //D.print("reading preResponse3 " # debug_show(dataResponse));
        let ?preResponse3 = await childv1.read(999) else D.trap("bad read preResponse3");

        D.print("data was " # debug_show(preResponse2, preResponse3));

        let preResponse4 = await childv1.putData({
          one = 55;
          two = "test55";
          three = 55 : Nat64;
        }) else D.trap("bad read preResponse4");


        //mem should be full, try to put one more object

        //upgrade it

        let childv2 = await (system Child2.Child2)(#upgrade childv1)();

        D.print("upgrade finished " # debug_show(Principal.fromActor(childv2)));


        //check that the memory endured
        let ?dataResponse2 = await childv1.read(0) else D.trap("bad read dataResponse2");
        let ?dataResponse3 = await childv1.read(999) else D.trap("bad read dataResponse3");
        D.print("data was " # debug_show(dataResponse2, dataResponse3));

        let finalStats = await childv1.stats() else D.trap("bad read finalStats");
        D.print("stats were " # debug_show(finalStats));


        //test responses

        let suite = S.suite(
            "test upgrade",
            [

                S.test(
                    "fail if stats don't match",
                    dataResponse.itemCount,
                    M.equals<Nat>(T.nat(105_270)), //max pages is 64 and this is the cutoff
                ), 
                S.test(
                    "fail if stats don't match",
                    dataResponse.currentPages,
                    M.equals<Nat64>(T.nat64(64)), //max pages is 64 and this is the cutoff
                ), 
                S.test(
                    "fail if can't read memory",
                    preResponse2.one,
                    M.equals<Nat>(T.nat(0)),
                ), 
                S.test(
                    "fail if can't read whole memeory",
                    preResponse3.one,
                    M.equals<Nat>(T.nat(999)),
                ), 
                S.test(
                    "fail if can't read memory after upgrade",
                    dataResponse2.one,
                    M.equals<Nat>(T.nat(0)),
                ), 
                 S.test(
                    "fail if can't read whole memory after upgrade",
                    dataResponse3.one,
                    M.equals<Nat>(T.nat(999)),
                ), 
                 S.test(
                    "fail if writing data doesn't return full memory",
                    switch(preResponse4){
                      case(#err(#MemoryFull)) "correct response";
                      case(_) "wrong response" # debug_show(preResponse4);
                    },
                    M.equals<Text>(T.text("correct response")),
                ), 
               

            ],
        );

        

        S.run(suite);

        return #success;
    };

    public shared func testStableTypedIndex() : async { #success; #fail : Text } {
        
        //create a bucket canister
        D.print("testing StableIndex start");

        let childv1 = await Child1.Child1(?#StableTyped);

        D.print("have canister " # debug_show(Principal.fromActor(childv1)));

        //load it with data

        let dataResponse = await childv1.putLotsOfTypedData(200000);

        D.print("data was put " # debug_show(dataResponse));

        //check that the memory endured
        D.print("reading preResponse2 " # debug_show(dataResponse));
        let ?preResponse2 = await childv1.readTyped(0) else D.trap("bad read preResponse2");
        D.print("reading preResponse3 " # debug_show(dataResponse));
        let ?preResponse3 = await childv1.readTyped(999) else D.trap("bad read preResponse3");

        D.print("data was " # debug_show(preResponse2, preResponse3));

        let preResponse4 = await childv1.putData({
          one = 55;
          two = "test55";
          three = 55 : Nat64;
        }) else D.trap("bad read preResponse4");


        //mem should be full, try to put one more object

        //upgrade it

        let childv2 = await (system Child2.Child2)(#upgrade childv1)();

        D.print("upgrade finished " # debug_show(Principal.fromActor(childv2)));


        //check that the memory endured
        let ?dataResponse2 = await childv1.readTyped(0) else D.trap("bad read dataResponse2");
        let ?dataResponse3 = await childv1.readTyped(999) else D.trap("bad read dataResponse3");
        D.print("data was " # debug_show(dataResponse2, dataResponse3));

        let finalStats = await childv1.stats() else D.trap("bad read finalStats");
        D.print("stats were " # debug_show(finalStats));


        //test responses

        let suite = S.suite(
            "test upgrade",
            [

                S.test(
                    "fail if stats don't match",
                    dataResponse.itemCount,
                    M.equals<Nat>(T.nat(121_813)), //max pages is 64 and this is the cutoff
                ), 
                S.test(
                    "fail if stats don't match",
                    dataResponse.currentPages,
                    M.equals<Nat64>(T.nat64(64)), //max pages is 64 and this is the cutoff
                ), 
                S.test(
                    "fail if can't read memory",
                    switch(preResponse2){
                      case(#TestType1(val)){
                        if(val.one == 0){
                          "correct response";
                        } else {
                          "wrong response"
                        };
                      };
                      case(_) "wrong response";
                    },
                    M.equals<Text>(T.text("correct response")),
                ), 
                S.test(
                    "fail if can't read whole memeory",
                    switch(preResponse3){
                      case(#TestType3(val)){
                        switch(val.five){
                          case(#six) "correct response";
                          case(_) "wrong response"
                        };
                      };
                      case(_) "wrong response";
                    },
                    M.equals<Text>(T.text("correct response")),
                ), 
                S.test(
                    "fail if can't read memory after upgrade",
                    switch(dataResponse2){
                      case(#TestType1(val)){
                        if(val.one == 0){
                          "correct response";
                        } else {
                          "wrong response"
                        };
                      };
                      case(_) "wrong response";
                    },
                    M.equals<Text>(T.text("correct response")),
                ), 
                 S.test(
                    "fail if can't read whole memory after upgrade",
                     switch(dataResponse3){
                      case(#TestType3(val)){
                        switch(val.five){
                          case(#six) "correct response";
                          case(_) "wrong response"
                        };
                      };
                      case(_) "wrong response";
                    },
                    M.equals<Text>(T.text("correct response")),
                ), 
                 S.test(
                    "fail if writing data doesn't return full memory",
                    switch(preResponse4){
                      case(#err(#MemoryFull)) "correct response";
                      case(_) "wrong response" # debug_show(preResponse4);
                    },
                    M.equals<Text>(T.text("correct response")),
                ), 
               

            ],
        );

        

        S.run(suite);

        return #success;
    };

    /// This test ensures that a canister can swap out one memory for another.  This could be 
    /// useful if the entire stream needs to be upgraded to a new type.
    public shared func testSwap() : async { #success; #fail : Text } {
        //create a bucket canister
        D.print("testing swap start");

        let childv1 = await Child1.Child1(null);

        D.print("have canister " # debug_show(Principal.fromActor(childv1)));

        //load it with data

        let dataResponse = await childv1.putData({
          one = 1;
          two = "two";
          three = 3 : Nat64
        });

        D.print("data was put " # debug_show(dataResponse));

        //check that the memory endured
        //D.print("reading preResponse2 " # debug_show(dataResponse));
        let ?preResponse2 = await childv1.read(0) else D.trap("bad read preResponse2");

        D.print("data was " # debug_show(preResponse2));

        let preResponse4 = await childv1.swapMemory() else D.trap("bad read preResponse4");


        //should have new object

        let ?postResponse2 = await childv1.read(0) else D.trap("bad read preResponse2");

        //upgrade it

        let finalStats = await childv1.stats() else D.trap("bad read finalStats");
        D.print("stats were " # debug_show(finalStats));


        //test responses

        let suite = S.suite(
            "test swap",
            [
                S.test(
                    "fail if can't read memory",
                    preResponse2.one,
                    M.equals<Nat>(T.nat(1)),
                ), 
               
                S.test(
                    "fail if memory doesn't change after swap",
                    postResponse2.one,
                    M.equals<Nat>(T.nat(55)),
                ), 
                 S.test(
                    "fail max pages isn't smaller",
                    finalStats.maxPages,
                    M.equals<Nat64>(T.nat64(32)),
                ), 
                
               

            ],
        );

        

        S.run(suite);

        return #success;
    };

    public shared func testBigData() : async { #success; #fail : Text } {
        try{
          //create a bucket canister
          D.print("testing BigData");

          // Use #Stable mode to keep index in stable memory instead of Wasm heap
          let childv1 = await Child1.Child1(?#Stable);

          D.print("have canister " # debug_show(Principal.fromActor(childv1)));

          //update max beyond reasonable limit
          let maxPagesResponse= await childv1.updateMaxPages(62501); //should be one more than default

          //load it with data
          var tracker = 0;
          
          label repeater loop{
            let dataResponseFill = await childv1.putLotsOfData(2000000);
            let dataResponseFill2 = await childv1.putLotsOfData(2000000);
            let dataResponseFill3 = await childv1.putLotsOfData(2000000);
            let dataResponseFill4 = await childv1.putLotsOfData(2000000);
            let dataResponseFill5 = await childv1.putLotsOfData(2000000);

            D.print("finished loop " # debug_show(tracker));

            tracker += 1;
            if(tracker >= 11) break repeater;
          };
          

          //D.print("data was put " # debug_show(dataResponseFill));

          //check that the memory endured
          //D.print("reading preResponse2 " # debug_show(dataResponse));
          let ?preResponse2 = await childv1.read(0) else D.trap("bad read preResponse2");
          //D.print("reading preResponse3 " # debug_show(dataResponse));
          let ?preResponse3 = await childv1.read(999) else D.trap("bad read preResponse3");

          D.print("data was " # debug_show(preResponse2, preResponse3));

          let preResponse4 = await childv1.putData({
            one = 55;
            two = "test55";
            three = 55 : Nat64;
          }) else D.trap("bad read preResponse4");

          //upgrade it

          let childv2 = await (system Child2.Child2)(#upgrade childv1)();

          D.print("upgrade finished " # debug_show(Principal.fromActor(childv2)));


          //check that the memory endured
          let ?dataResponse2 = await childv1.read(0) else D.trap("bad read dataResponse2");
          let ?dataResponse3 = await childv1.read(999) else D.trap("bad read dataResponse3");
          D.print("data was " # debug_show(dataResponse2, dataResponse3));

          let finalStats = await childv1.stats() else D.trap("bad read finalStats");
          D.print("stats were " # debug_show(finalStats));


          //test responses

          let suite = S.suite(
              "test upgrade",
              [

                  
                  
                  S.test(
                      "fail if can't read memory",
                      preResponse2.one,
                      M.equals<Nat>(T.nat(0)),
                  ), 
                  S.test(
                      "fail if can't read whole memeory",
                      preResponse3.one,
                      M.equals<Nat>(T.nat(999)),
                  ), 
                  S.test(
                      "fail if can't read memory after upgrade",
                      dataResponse2.one,
                      M.equals<Nat>(T.nat(0)),
                  ), 
                  S.test(
                      "fail if can't read whole memory after upgrade",
                      dataResponse3.one,
                      M.equals<Nat>(T.nat(999)),
                  ), 
                  S.test(
                      "fail if writing data doesn't return full memory",
                      switch(preResponse4){
                        case(#err(#MemoryFull)) "correct response";
                        case(#err(#IndexFull)) "correct response";
                        case(_) "wrong response" # debug_show(preResponse4);
                      },
                      M.equals<Text>(T.text("correct response")),
                  ), 
                

              ],
          );

          

          S.run(suite);
        } catch (e){
          D.print("error occured " # Error.message(e));
          return #fail(Error.message(e));
        };

        return #success;
    };

    /// Test that region-based stable memory calculation produces reasonable results
    /// compared to IC stable memory size
    public shared func testStableMemoryComparison() : async { #success; #fail : Text } {
        D.print("testing StableMemoryComparison");

        // Test with #Stable mode (has separate index region)
        let childStable = await Child1.Child1(?#Stable);

        // Add some data
        for(i in [1, 2, 3, 4, 5].vals()){
          ignore await childStable.putData({
            one = i;
            two = "test" # debug_show(i);
            three = 15;
          });
        };

        let comparisonStable = await childStable.stableMemoryComparison();
        D.print("Stable mode comparison: " # debug_show(comparisonStable));

        // Test with #Managed mode (no index region)
        let childManaged = await Child1.Child1(?#Managed);

        // Add some data
        for(i in [1, 2, 3, 4, 5].vals()){
          ignore await childManaged.putData({
            one = i;
            two = "test" # debug_show(i);
            three = 15;
          });
        };

        let comparisonManaged = await childManaged.stableMemoryComparison();
        D.print("Managed mode comparison: " # debug_show(comparisonManaged));

        // Test with #StableTyped mode
        let childTyped = await Child1.Child1(?#StableTyped);

        // Add some typed data using putLotsOfTypedData
        ignore await childTyped.putLotsOfTypedData(5);

        let comparisonTyped = await childTyped.stableMemoryComparison();
        D.print("StableTyped mode comparison: " # debug_show(comparisonTyped));

        let suite = S.suite(
            "test stable memory comparison",
            [
                // For #Stable mode: region-based should include both data and index pages
                S.test(
                    "Stable mode: regionBasedPages should be > 0",
                    comparisonStable.regionBasedPages > 0,
                    M.equals<Bool>(T.bool(true)),
                ),
                S.test(
                    "Stable mode: dataPages should be > 0",
                    comparisonStable.dataPages > 0,
                    M.equals<Bool>(T.bool(true)),
                ),
                S.test(
                    "Stable mode: indexPages should be > 0 for #Stable",
                    comparisonStable.indexPages > 0,
                    M.equals<Bool>(T.bool(true)),
                ),
                S.test(
                    "Stable mode: regionBasedPages should equal dataPages + indexPages",
                    comparisonStable.regionBasedPages == comparisonStable.dataPages + comparisonStable.indexPages,
                    M.equals<Bool>(T.bool(true)),
                ),
                // NOTE: Prim.stableMemorySize() returns legacy stable memory, NOT region memory.
                // Region memory is allocated from a separate internal pool managed by the runtime.
                // So icStableMemoryPages will typically be 0 when only using Region API.
                // This test verifies that behavior - region-based stats are the correct measure.
                S.test(
                    "Stable mode: icStableMemoryPages is separate from region memory (typically 0)",
                    comparisonStable.icStableMemoryPages == 0,
                    M.equals<Bool>(T.bool(true)),
                ),

                // For #Managed mode: no index region, so indexPages should be 0
                S.test(
                    "Managed mode: indexPages should be 0",
                    comparisonManaged.indexPages == 0,
                    M.equals<Bool>(T.bool(true)),
                ),
                S.test(
                    "Managed mode: regionBasedPages should equal dataPages",
                    comparisonManaged.regionBasedPages == comparisonManaged.dataPages,
                    M.equals<Bool>(T.bool(true)),
                ),

                // For #StableTyped mode: should also have index pages
                S.test(
                    "StableTyped mode: indexPages should be > 0",
                    comparisonTyped.indexPages > 0,
                    M.equals<Bool>(T.bool(true)),
                ),
            ],
        );

        S.run(suite);

        return #success;
    };

};