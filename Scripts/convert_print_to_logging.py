#!/usr/bin/env python3
"""
Script to convert remaining print statements to ZeezLogger calls
Part of Checkpoint 2.3: Logging Infrastructure
"""

import os
import re
import sys
from pathlib import Path

# Map of file patterns to appropriate logger categories
LOGGER_MAPPING = {
    # Core system files
    'PersistenceController': 'coreData',
    'ErrorManager': 'error',
    'ErrorTracker': 'error',
    'MockDataGenerator': 'mockData',
    'AnalyticsManager': 'analytics',
    'BackgroundTaskManager': 'background',
    
    # Sleep tracking
    'SleepAnalyzer': 'sleepTracking',
    'SleepSession': 'sleepTracking',
    'SleepStage': 'sleepTracking',
    'SleepQuality': 'sleepTracking',
    'SleepCycle': 'sleepTracking',
    'SleepDebt': 'sleepTracking',
    'SleepPosition': 'sleepTracking',
    
    # Learning system
    'Learn': 'learning',
    
    # Environmental
    'Environmental': 'environment',
    'Environment': 'environment',
    
    # Alarm system
    'Alarm': 'alarm',
    'WakeUp': 'alarm',
    
    # UI files
    'View': 'ui',
    'Card': 'ui',
    'Component': 'ui',
    
    # Default fallback
    'default': 'app'
}

def determine_logger_category(file_path):
    """Determine appropriate logger category based on file path and name"""
    file_name = Path(file_path).stem
    
    # Check specific mappings first
    for pattern, category in LOGGER_MAPPING.items():
        if pattern in file_name:
            return category
    
    # Check directory structure
    if '/Sleep/' in file_path:
        return 'sleepTracking'
    elif '/Learn/' in file_path:
        return 'learning'
    elif '/Environment/' in file_path:
        return 'environment'
    elif '/Alarm/' in file_path:
        return 'alarm'
    elif '/Views/' in file_path:
        return 'ui'
    
    return 'app'  # Default fallback

def convert_print_statement(line, logger_category):
    """Convert a print statement to appropriate ZeezLogger call"""
    # Match various print statement patterns
    patterns = [
        # Simple print with string
        (r'print\("([^"]+)"\)', r'ZeezLogger.debug(ZeezLogger.\1, "\2")'),
        
        # Print with interpolation
        (r'print\("([^"]*\\[^"]*[^"]+)"\)', r'ZeezLogger.debug(ZeezLogger.\1, "\2")'),
        
        # Print with multiple arguments
        (r'print\("([^"]+)"[^)]*\)', r'ZeezLogger.debug(ZeezLogger.\1, "\2")'),
        
        # Error print statements (contain "error" or "Error")
        (r'print\("([^"]*[Ee]rror[^"]*)"[^)]*\)', r'ZeezLogger.error(ZeezLogger.\1, "\2")'),
        
        # Success/info print statements
        (r'print\("([^"]*[Ss]uccess[^"]*)"[^)]*\)', r'ZeezLogger.info(ZeezLogger.\1, "\2")'),
    ]
    
    for pattern, replacement in patterns:
        match = re.search(pattern, line)
        if match:
            return re.sub(pattern, replacement.replace('\\1', logger_category), line)
    
    return line

def process_file(file_path):
    """Process a single Swift file to convert print statements"""
    logger_category = determine_logger_category(file_path)
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        lines = content.split('\n')
        modified = False
        new_lines = []
        
        for line in lines:
            if 'print(' in line and not line.strip().startswith('//'):
                new_line = convert_print_statement(line, logger_category)
                if new_line != line:
                    modified = True
                    print(f"  Converted: {line.strip()} -> {new_line.strip()}")
                new_lines.append(new_line)
            else:
                new_lines.append(line)
        
        if modified:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(new_lines))
            return True
        
        return False
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    """Main function to process all Swift files"""
    zeez_dir = Path(__file__).parent.parent / "Zeez"
    
    if not zeez_dir.exists():
        print("Error: Zeez directory not found")
        sys.exit(1)
    
    swift_files = list(zeez_dir.rglob("*.swift"))
    processed_count = 0
    
    print(f"Processing {len(swift_files)} Swift files...")
    
    for file_path in swift_files:
        # Skip the ZeezLogger.swift file itself
        if file_path.name == "ZeezLogger.swift":
            continue
            
        print(f"\nProcessing: {file_path.relative_to(zeez_dir.parent)}")
        
        if process_file(file_path):
            processed_count += 1
    
    print(f"\n✅ Completed: {processed_count} files modified")
    print("Don't forget to:")
    print("1. Build the project to check for compilation errors")
    print("2. Test that logging works in debug builds")
    print("3. Verify no debug output in release builds")

if __name__ == "__main__":
    main()