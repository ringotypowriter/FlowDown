#!/usr/bin/env python3
"""
i18n Manager for FlowDown
Checks localization string translation status.
"""

import json
import argparse
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass


@dataclass
class TranslationStatus:
    """Represents the status of a translation."""
    key: str
    language: str
    state: str
    value: Optional[str] = None
    is_missing: bool = False


class LocalizableManager:
    """Manages Localizable.xcstrings file operations."""
    
    def __init__(self, file_path: str):
        self.file_path = Path(file_path)
        self.data: Dict = {}
        self.load()
    
    def load(self) -> None:
        """Load the Localizable.xcstrings file."""
        if not self.file_path.exists():
            raise FileNotFoundError(f"File not found: {self.file_path}")
        
        with open(self.file_path, 'r', encoding='utf-8') as f:
            self.data = json.load(f)
    
    def save(self) -> None:
        """Save the Localizable.xcstrings file."""
        with open(self.file_path, 'w', encoding='utf-8') as f:
            json.dump(self.data, f, ensure_ascii=False, indent=2)
    
    def get_all_languages(self) -> set:
        """Get all languages present in the strings."""
        languages = set()
        for key, entry in self.data.get('strings', {}).items():
            if isinstance(entry, dict) and 'localizations' in entry:
                languages.update(entry['localizations'].keys())
        return languages
    
    def get_source_language(self) -> str:
        """Get the source language."""
        return self.data.get('sourceLanguage', 'en')
    
    def check_translations(self, language: str = 'zh-Hans') -> Tuple[List[TranslationStatus], int, int]:
        """
        Check for missing or incomplete translations.
        
        Returns:
            Tuple of (missing_translations, total_strings, translated_count)
        """
        missing = []
        total = 0
        translated = 0
        
        strings = self.data.get('strings', {})
        
        for key, entry in strings.items():
            # Skip empty keys and special entries
            if not key or key in ['', '...']:
                continue
            
            total += 1
            
            if not isinstance(entry, dict):
                continue
            
            # Check if shouldTranslate is False
            if entry.get('shouldTranslate') is False:
                translated += 1
                continue
            
            localizations = entry.get('localizations', {})
            
            # Check if localizations is empty or language not present
            if not localizations or language not in localizations:
                missing.append(TranslationStatus(
                    key=key,
                    language=language,
                    state='missing',
                    is_missing=True
                ))
            else:
                lang_entry = localizations[language]
                if isinstance(lang_entry, dict) and 'stringUnit' in lang_entry:
                    string_unit = lang_entry['stringUnit']
                    state = string_unit.get('state', 'unknown')
                    value = string_unit.get('value', '')
                    
                    if state == 'translated' and value:
                        translated += 1
                    else:
                        missing.append(TranslationStatus(
                            key=key,
                            language=language,
                            state=state,
                            value=value,
                            is_missing=state != 'translated' or not value
                        ))
        
        return missing, total, translated
    
    
    def get_statistics(self, language: str = 'zh-Hans') -> Dict:
        """Get translation statistics."""
        missing, total, translated = self.check_translations(language)
        
        return {
            'total_strings': total,
            'translated': translated,
            'missing': len(missing),
            'completion_rate': f"{(translated / total * 100):.1f}%" if total > 0 else "0%",
            'language': language
        }


def print_check_report(manager: LocalizableManager, language: str) -> None:
    """Print a detailed check report."""
    missing, total, translated = manager.check_translations(language)
    stats = manager.get_statistics(language)
    
    print(f"\n{'='*70}")
    print(f"Translation Check Report for {language}")
    print(f"{'='*70}")
    print(f"Total strings: {stats['total_strings']}")
    print(f"Translated: {stats['translated']}")
    print(f"Missing/Incomplete: {stats['missing']}")
    print(f"Completion rate: {stats['completion_rate']}")
    print(f"{'='*70}\n")
    
    if missing:
        print(f"Missing or incomplete translations in {language} ({len(missing)}):\n")
        for i, item in enumerate(missing[:20], 1):  # Show first 20
            print(f"{i}. [{item.state}] {item.key[:60]}")
            if item.value:
                print(f"   Current: {item.value[:60]}")
        
        if len(missing) > 20:
            print(f"\n... and {len(missing) - 20} more")
    else:
        print(f"✅ All translations for {language} are complete!")


def main():
    parser = argparse.ArgumentParser(
        description='FlowDown i18n Manager - Check localization strings',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Check translation status for zh-Hans
  python i18n_manager.py --file Localizable.xcstrings
  
  # Check specific language
  python i18n_manager.py --language en --file Localizable.xcstrings
        """
    )
    
    parser.add_argument(
        '--file',
        type=str,
        required=True,
        help='Path to Localizable.xcstrings file'
    )
    
    parser.add_argument(
        '--language',
        type=str,
        default='zh-Hans',
        help='Target language (default: zh-Hans)'
    )
    
    parser.add_argument(
        '--check',
        action='store_true',
        help='Check for missing translations'
    )
    
    args = parser.parse_args()
    
    try:
        manager = LocalizableManager(args.file)
        
        # Default: show check report
        print_check_report(manager, args.language)
    
    except FileNotFoundError as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ Error parsing JSON: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
