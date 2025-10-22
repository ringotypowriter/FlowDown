#!/usr/bin/env python3
"""
Update or insert translation keys into an Xcode .xcstrings JSON file.
Usage:
  python i18n_update_keys.py <xcstrings_path>
"""
import json
import sys
from pathlib import Path

UPDATES = {
    "Enable iCloud sync to keep data consistent across your devices. Turning off does not delete existing data.": "启用 iCloud 同步以保持多设备数据一致。关闭不会删除现有数据。",
    "When sync is off, no new changes are shared. Existing data remains intact. Re‑enable sync to fetch the latest state before resuming.": "关闭同步后将不再共享新更改。现有数据保持不变。重新开启同步会先获取最新状态再继续。",
    "Refresh from iCloud": "手动从 iCloud 刷新",
    "Manually fetch the latest changes from iCloud.": "手动获取 iCloud 上的最新更改。",
    "Refreshing...": "正在刷新...",
    "Full Refresh from iCloud": "完全刷新 iCloud 数据",
    "Rebuild sync state and fetch everything new from iCloud. Local data is preserved.": "重建同步状态并拉取 iCloud 上的所有最新内容。本地数据将被保留。",
    "Sync Scope": "同步范围",
    "Configure which data groups sync with iCloud.": "在此配置哪些数据分组参与 iCloud 同步。",
    "Conversations, Messages, Attachments": "会话、消息、附件",
    "Sync chats and their messages and files.": "同步会话及其消息与文件。",
    "Memory": "记忆",
    "Sync your AI memory entries.": "同步你的 AI 记忆条目。",
    "MCP Servers": "MCP 服务器",
    "Sync configured MCP connections.": "同步已配置的 MCP 连接。",
    "Models": "模型",
    "Sync cloud model configurations.": "同步云端模型配置。",
    "Turning off sync only pauses future updates. Existing data stays in place. Re‑enable later to fetch and resume syncing.": "关闭同步仅暂停后续更新；现有数据保持不变。稍后重新开启将先获取最新状态再继续同步。",
    "Manual Refresh Mode": "手动刷新模式",
    "Pause automatic background syncing. Use Refresh to pull changes when needed.": "暂停自动后台同步；需要时使用“刷新”手动拉取。"
}

def set_value(strings, key, zh):
    entry = strings.setdefault(key, {})
    entry.setdefault('extractionState', 'manual')
    locs = entry.setdefault('localizations', {})
    zh_entry = locs.setdefault('zh-Hans', {})
    zh_entry['stringUnit'] = {'state': 'translated', 'value': zh}

def main():
    if len(sys.argv) < 2:
        print('Usage: i18n_update_keys.py <xcstrings_path>')
        sys.exit(2)
    p = Path(sys.argv[1])
    data = json.loads(p.read_text(encoding='utf-8'))
    strings = data.setdefault('strings', {})
    for k, v in UPDATES.items():
        set_value(strings, k, v)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'Updated {len(UPDATES)} keys in {p}')

if __name__ == '__main__':
    main()
