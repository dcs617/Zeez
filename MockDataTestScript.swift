#!/usr/bin/env swift

// Test script to verify mock data behavior
// This is just for documentation - the actual fixes are in the code

/*
 FIXES IMPLEMENTED:
 
 1. Mock Data Generation Issue:
    - Changed MockDataGenerator to use "Mock Data - iPhone" as deviceIdentifier
    - Updated RealDataManager.hasRealData() to properly detect non-mock sessions
    - Updated fetchMockSessions to handle legacy "iPhone" identifiers
    
 2. Clear Mock Data Issue:
    - Fixed predicate in fetchMockSessions to include legacy "iPhone" sessions
    - This ensures all generated mock data is properly identified and cleared
    
 3. DataImportView Presentation Issue:
    - Implemented single modal state management in SettingsView
    - Used Binding wrappers to prevent multiple simultaneous presentations
    - Applied same pattern to DataImportView's internal modals
    
 TESTING:
 1. Launch app - should not generate mock data if real data exists
 2. Clear mock data - should properly clear all mock sessions
 3. Import data - modal should stay open without crashes
 
 The console should now show:
 - "Found X real (non-mock) sleep sessions" when checking for real data  
 - "Successfully deleted Y mock sessions" when clearing (Y > 0 if mock data exists)
 - No presentation conflicts when opening import modal
*/

print("Mock data fixes implemented. See code comments above for details.")