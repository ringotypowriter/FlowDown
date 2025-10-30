#!/usr/bin/env python3
"""
Update missing i18n translations in Localizable.xcstrings.
This script adds missing English localizations and fixes 'new' state translations.
"""

import json
import sys
import os

def update_translations(file_path):
    """Update missing translations in the xcstrings file."""
    
    # Read the file
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"❌ File not found: {file_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ JSON decode error in {file_path}: {e}")
        sys.exit(1)
    
    strings = data['strings']
    
    # Count changes
    added_count = 0
    fixed_count = 0
    
    # Iterate through all strings
    for key, value in strings.items():
        # Skip strings marked as shouldTranslate=false
        if not value.get('shouldTranslate', True):
            continue
        
        # Get existing localizations
        locs = value.get('localizations', {})
        
        # Check if 'en' localization is missing
        if 'en' not in locs:
            # Add English localization with the key as the value
            if 'localizations' not in value:
                value['localizations'] = {}
            
            value['localizations']['en'] = {
                'stringUnit': {
                    'state': 'translated',
                    'value': key
                }
            }
            added_count += 1
        else:
            # Check if the state is 'new' and fix it
            en_loc = locs['en']
            if en_loc.get('stringUnit', {}).get('state') == 'new':
                # Set state to 'translated' and use the key as value if empty
                if not en_loc.get('stringUnit', {}).get('value', '').strip():
                    en_loc['stringUnit']['value'] = key
                en_loc['stringUnit']['state'] = 'translated'
                fixed_count += 1
    
    # Write the updated file
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"✅ Successfully updated {file_path}")
        print(f"   - Added {added_count} missing English localizations")
        print(f"   - Fixed {fixed_count} 'new' state translations")
        return True
    except Exception as e:
        print(f"❌ Error writing file: {e}")
        sys.exit(1)

if __name__ == '__main__':
    # Default path to the Localizable.xcstrings file
    default_file_path = os.path.join(
        os.path.dirname(__file__), 
        '..', '..', 
        'FlowDown', 
        'Resources', 
        'Localizable.xcstrings'
    )
    
    # Allow overriding the file path via command line argument
    file_path = sys.argv[1] if len(sys.argv) > 1 else default_file_path
    
    print(f"📝 Updating translations in: {file_path}")
    update_translations(file_path)
