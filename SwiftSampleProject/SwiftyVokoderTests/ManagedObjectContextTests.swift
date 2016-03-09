//
//  ManagedObjectContextTests.swift
//  SwiftSampleProject
//
//  Created by Carl Hill-Popper on 2/9/16.
//  Copyright © 2016 Vokal.
//

import XCTest
import Vokoder
@testable import SwiftyVokoder

class ManagedObjectContextTests: XCTestCase {

    let manager = VOKCoreDataManager.sharedInstance()
    
    override func setUp() {
        super.setUp()
        self.manager.resetCoreData()
        self.manager.setResource("CoreDataModel", database: "CoreDataModel.sqlite")
        
        Stop.vok_import(CTAData.allStopDictionaries())
        self.manager.saveMainContextAndWait()
    }
    
    func testContextChain() {
        let tempContext = self.manager.temporaryContext()
        //temp context is a child of the main context
        XCTAssertEqual(tempContext.parentContext, self.manager.managedObjectContext)
        //main context has a private parent context
        XCTAssertNotNil(self.manager.managedObjectContext.parentContext)
    }
    
    func testDeletingObjectsOnTempContextGetsSavedToMainContext() {
        //get a temp context, delete from temp, save to main, verify deleted on main
        
        let tempContext = self.manager.temporaryContext()
        
        let countOfStations = self.manager.countForClass(Station.self)
        XCTAssertGreaterThan(countOfStations, 0)
        
        tempContext.performBlockAndWait {
            self.manager.deleteAllObjectsOfClass(Station.self, context: tempContext)
        }
        self.manager.saveAndMergeWithMainContextAndWait(tempContext)
        
        let updatedCountOfStations = self.manager.countForClass(Station.self)
        XCTAssertEqual(updatedCountOfStations, 0)
        XCTAssertNotEqual(countOfStations, updatedCountOfStations)
    }
    
    func testAddingObjectsOnTempContextGetsSavedToMainContext() {
        //get a temp context, add to temp, save to main, verify added to main
        
        let tempContext = self.manager.temporaryContext()

        let countOfTrainLines = self.manager.countForClass(TrainLine.self)
        
        tempContext.performBlockAndWait {
            let silverLine = TrainLine.vok_newInstanceWithContext(tempContext)
            silverLine.identifier = "SLV"
            silverLine.name = "Silver Line"
        }
        self.manager.saveAndMergeWithMainContextAndWait(tempContext)
     
        let updatedCount = self.manager.countForClass(TrainLine.self)
        XCTAssertEqual(updatedCount, countOfTrainLines + 1)
    }
    
    func testSaveWithoutWaitingEventuallySaves() {
        let countOfStations = self.manager.countForClass(Station.self)
        XCTAssertGreaterThan(countOfStations, 0)

        self.manager.deleteAllObjectsOfClass(Station.self, context: nil)
        
        self.expectationForNotification(NSManagedObjectContextDidSaveNotification,
            object: self.manager.managedObjectContext) { _ in
                
                let updatedCountOfStations = self.manager.countForClass(Station.self)
                XCTAssertEqual(updatedCountOfStations, 0)
                XCTAssertNotEqual(countOfStations, updatedCountOfStations)
                
                return true
        }
        
        guard let rootContext = self.manager.managedObjectContext.parentContext else {
            XCTFail("Expecting the main context to have a parent context")
            return
        }
        self.expectationForNotification(NSManagedObjectContextDidSaveNotification,
            object: rootContext) { _ in
                
                let updatedCountOfStations = self.manager.countForClass(Station.self, forContext: rootContext)
                XCTAssertEqual(updatedCountOfStations, 0)
                XCTAssertNotEqual(countOfStations, updatedCountOfStations)
                
                return true
        }
    
        self.manager.saveMainContext()
        
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testSaveAndMergeWithMainContextSavesGrandChildren() {
        let childContext = self.manager.temporaryContext()
        let grandChildContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        grandChildContext.parentContext = childContext
        
        let countOfStations = self.manager.countForClass(Station.self)
        XCTAssertGreaterThan(countOfStations, 0)
        
        grandChildContext.performBlockAndWait {
            self.manager.deleteAllObjectsOfClass(Station.self, context: grandChildContext)
        }
        
        self.manager.saveAndMergeWithMainContextAndWait(grandChildContext)
        
        let updatedCountOfStations = self.manager.countForClass(Station.self)
        XCTAssertEqual(updatedCountOfStations, 0)
        XCTAssertNotEqual(countOfStations, updatedCountOfStations)
    }
    
    func testUnsavedMainContextChangesGetPassedToTempContexts() {
        let countOfStations = self.manager.countForClass(Station.self)
        XCTAssert(countOfStations > 0)

        //temp contexts should reflect any changes to their parent context (the main context)
        //regardless of if they were created before...
        let childContextBeforeChanges = self.manager.temporaryContext()
        //...changes are made to the parent context...
        self.manager.deleteAllObjectsOfClass(Station.self, context: nil)
        //...or after the changes are made
        let childContextAfterChanges = self.manager.temporaryContext()

        let childCountOfStations = self.manager.countForClass(Station.self, forContext: childContextBeforeChanges)
        XCTAssertNotEqual(countOfStations, childCountOfStations)
        XCTAssertEqual(childCountOfStations, 0)
        
        let otherChildCountOfStations = self.manager.countForClass(Station.self, forContext: childContextAfterChanges)
        XCTAssertNotEqual(countOfStations, otherChildCountOfStations)
        XCTAssertEqual(otherChildCountOfStations, childCountOfStations)
        XCTAssertEqual(otherChildCountOfStations, 0)
    }
    
    func testUnsavedTempContextChangesDoNotGetPassedToMainContext() {
        let countOfStations = self.manager.countForClass(Station.self)
        XCTAssertGreaterThan(countOfStations, 0)

        let childContext = self.manager.temporaryContext()
        self.manager.deleteAllObjectsOfClass(Station.self, context: childContext)
        
        let childCountOfStations = self.manager.countForClass(Station.self, forContext: childContext)
        XCTAssertNotEqual(countOfStations, childCountOfStations)
        XCTAssertEqual(childCountOfStations, 0)
        
        let updatedCountOfStations = self.manager.countForClass(Station.self)
        XCTAssertEqual(countOfStations, updatedCountOfStations)
    }
}