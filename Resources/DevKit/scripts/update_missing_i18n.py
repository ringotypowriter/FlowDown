#!/usr/bin/env python3
"""
Update missing i18n translations in Localizable.xcstrings.
This script adds missing English localizations and fixes 'new' state translations.
"""

import json
import sys
import os

# you can modify this script to populate localization strings as needed
# just remember to remove the entries from NEW_STRINGS after committing
NEW_STRINGS: dict[str, dict[str, str]] = {
    "Search saved conversations by keyword and return formatted summaries.": {
        "zh-Hans": "按关键字搜索已保存的会话，并返回格式化摘要。",
    },
    "Result Limit": {
        "zh-Hans": "结果上限",
    },
    "How many results should FlowDown return?": {
        "zh-Hans": "FlowDown 应返回多少条结果？",
    },
    "Browse recent conversations": {
        "zh-Hans": "浏览最近的对话",
    },
    "Classify the provided content using the candidate list": {
        "zh-Hans": "使用候选列表对提供的内容进行分类",
    },
    "Classify the provided image using the candidate list": {
        "zh-Hans": "使用候选列表对提供的图像进行分类",
    },
    "Create a blank conversation link": {
        "zh-Hans": "创建空白对话链接",
    },
    "Create a conversation link with a preset message": {
        "zh-Hans": "创建带预设消息的对话链接",
    },
    "Enable Memory Tools": {
        "zh-Hans": "启用记忆工具",
    },
    "Fetch the latest conversation details": {
        "zh-Hans": "获取最新的对话详情",
    },
    "Generate Model Response": {
        "zh-Hans": "生成模型回复",
    },
    "Generate Model Response with Image": {
        "zh-Hans": "生成带图像的模型回复",
    },
    "If you are unsure, use '%@' for VALUE.": {
        "zh-Hans": "如果不确定，请将 VALUE 设置为“%@”。",
    },
    "List the key points from the text": {
        "zh-Hans": "列出文本中的关键要点",
    },
    "List the key points using the default model": {
        "zh-Hans": "使用默认模型列出关键要点",
    },
    "Make the text concise using the default model": {
        "zh-Hans": "使用默认模型使文本更简洁",
    },
    "Make the text more concise": {
        "zh-Hans": "让文本更加简洁",
    },
    "Respond only with XML formatted as <classification><label>VALUE</label></classification>, replacing VALUE with a label from the candidate list.": {
        "zh-Hans": "仅返回 XML 格式 <classification><label>VALUE</label></classification>，并将 VALUE 替换为候选列表中的标签。",
    },
    "Rewrite the text in a friendly tone using the default model": {
        "zh-Hans": "使用默认模型以友好语气改写文本",
    },
    "Rewrite the text in a friendly tone": {
        "zh-Hans": "以友好语气改写文本",
    },
    "Rewrite the text professionally using the default model": {
        "zh-Hans": "使用默认模型以专业语气改写文本",
    },
    "Rewrite the text with a friendly tone": {
        "zh-Hans": "使用友好语气改写文本",
    },
    "Rewrite the text with a professional tone": {
        "zh-Hans": "以专业语气改写文本",
    },
    "Search saved conversations by keyword": {
        "zh-Hans": "按关键字搜索已保存的对话",
    },
    "Select exactly one label from the candidate list.": {
        "zh-Hans": "仅从候选列表中选择一个标签。",
    },
    "Send your message with the default model": {
        "zh-Hans": "使用默认模型发送你的消息",
    },
    "Send your message with the default model and optional image": {
        "zh-Hans": "使用默认模型并可选图像发送你的消息",
    },
    "Send your message with the selected model": {
        "zh-Hans": "使用所选模型发送你的消息",
    },
    "Send your message with the selected model and optional image": {
        "zh-Hans": "使用所选模型并可选图像发送你的消息",
    },
    "Set the default conversation model": {
        "zh-Hans": "设置默认对话模型",
    },
    "Summarize the provided text": {
        "zh-Hans": "总结提供的文本",
    },
    "Summarize the provided text with the default model": {
        "zh-Hans": "使用默认模型总结提供的文本",
    },
}

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

    # Ensure new strings exist with provided translations
    for key, translations in NEW_STRINGS.items():
        entry = strings.setdefault(key, {})
        if entry.get('shouldTranslate') is False:
            entry.pop('shouldTranslate', None)

        locs = entry.setdefault('localizations', {})
        locs.setdefault('en', {
            'stringUnit': {
                'state': 'translated',
                'value': key,
            }
        })

        for language, value in translations.items():
            locs[language] = {
                'stringUnit': {
                    'state': 'translated',
                    'value': value,
                }
            }

    # Determine all languages present in the file (excluding ones marked shouldTranslate=false)
    languages: set[str] = set()
    for value in strings.values():
        locs = value.get('localizations', {})
        for lang in locs.keys():
            languages.add(lang)

    # Ensure English is always part of the language set
    languages.add('en')

    # Count changes
    added_count = 0
    fixed_count = 0
    filled_count = 0
    
    # Iterate through all strings
    for key, value in strings.items():
        # Skip strings marked as shouldTranslate=false
        if not value.get('shouldTranslate', True):
            continue
        
        # Ensure dictionary exists for modifications
        if 'localizations' not in value:
            value['localizations'] = {}

        locs = value['localizations']

        # Check if 'en' localization is missing
        if 'en' not in locs:
            locs['en'] = {
                'stringUnit': {
                    'state': 'translated',
                    'value': key
                }
            }
            added_count += 1

        # Ensure English localization is properly marked
        en_loc = locs['en']
        en_string_unit = en_loc.setdefault('stringUnit', {})
        if en_string_unit.get('state') == 'new':
            if not en_string_unit.get('value', '').strip():
                en_string_unit['value'] = key
            en_string_unit['state'] = 'translated'
            fixed_count += 1
        english_value = en_string_unit.get('value', key)

        # Fill missing localizations for other languages using English as fallback
        for language in languages:
            if language == 'en':
                continue

            string_unit = locs.get(language, {}).get('stringUnit')
            current_value = string_unit.get('value').strip() if string_unit and string_unit.get('value') else ''
            current_state = string_unit.get('state') if string_unit else None

            if language not in locs or not current_value:
                locs[language] = {
                    'stringUnit': {
                        'state': 'translated',
                        'value': english_value
                    }
                }
                filled_count += 1
            elif current_state == 'new':
                locs[language]['stringUnit']['state'] = 'translated'
                if not current_value:
                    locs[language]['stringUnit']['value'] = english_value
                filled_count += 1
    
    # Write the updated file
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"✅ Successfully updated {file_path}")
        print(f"   - Added {added_count} missing English localizations")
        print(f"   - Fixed {fixed_count} 'new' state translations")
        print(f"   - Filled {filled_count} fallback localizations")
        return True
    except Exception as e:
        print(f"❌ Error writing file: {e}")
        sys.exit(1)

if __name__ == '__main__':
    # Default path to the Localizable.xcstrings file
    default_file_path = os.path.join(
        os.path.dirname(__file__),
        '..', '..', '..',
        'FlowDown',
        'Resources',
        'Localizable.xcstrings'
    )
    
    # Allow overriding the file path via command line argument
    file_path = sys.argv[1] if len(sys.argv) > 1 else default_file_path
    
    print(f"📝 Updating translations in: {file_path}")
    update_translations(file_path)
