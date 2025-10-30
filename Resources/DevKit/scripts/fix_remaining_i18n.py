#!/usr/bin/env python3
"""
Fix remaining missing i18n translations.
Adds Chinese translations for strings that have English but are missing Chinese.
"""

import json
import sys
import os

# Mapping of English strings to Chinese translations
TRANSLATION_MAP = {
    "Export Image": "导出图像",
}

def fix_translations(file_path):
    """Fix remaining missing translations."""
    
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
    fixed_count = 0
    
    # Apply translations
    for english_key, chinese_value in TRANSLATION_MAP.items():
        if english_key in strings:
            value = strings[english_key]
            
            # Ensure localizations dict exists
            if 'localizations' not in value:
                value['localizations'] = {}
            
            # Add Chinese translation if missing
            if 'zh-Hans' not in value['localizations']:
                value['localizations']['zh-Hans'] = {
                    'stringUnit': {
                        'state': 'translated',
                        'value': chinese_value
                    }
                }
                fixed_count += 1
                print(f"✅ Added Chinese translation for: {english_key}")
    
    # Write the updated file
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"\n✅ Successfully updated {file_path}")
        print(f"   - Fixed {fixed_count} missing Chinese translations")
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
    
    print(f"📝 Fixing remaining translations in: {file_path}")
    fix_translations(file_path)
