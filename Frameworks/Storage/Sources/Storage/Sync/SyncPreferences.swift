//
//  SyncPreferences.swift
//  Storage
//
//  Created by AI on 2025/10/22.
//

import Foundation

/// User preferences controlling iCloud sync behavior and table groups.
public enum SyncPreferences {
    // MARK: - Keys

    private static let manualSyncKey = "com.flowdown.storage.sync.manual.enabled"

    private static let groupConversationsKey = "com.flowdown.storage.sync.group.conversations"
    private static let groupMemoryKey = "com.flowdown.storage.sync.group.memory"
    private static let groupMCPKey = "com.flowdown.storage.sync.group.mcp"
    private static let groupModelsKey = "com.flowdown.storage.sync.group.models"

    // MARK: - Manual Mode

    public static var isManualSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: manualSyncKey) }
        set { UserDefaults.standard.set(newValue, forKey: manualSyncKey) }
    }

    // MARK: - Group Toggles

    public enum Group: Sendable {
        case conversations // Conversation, Message, Attachment
        case memory        // Memory
        case mcp           // ModelContextServer
        case models        // CloudModel
    }

    public static func isGroupEnabled(_ group: Group) -> Bool {
        switch group {
        case .conversations:
            return UserDefaults.standard.object(forKey: groupConversationsKey) as? Bool ?? true
        case .memory:
            return UserDefaults.standard.object(forKey: groupMemoryKey) as? Bool ?? true
        case .mcp:
            return UserDefaults.standard.object(forKey: groupMCPKey) as? Bool ?? true
        case .models:
            return UserDefaults.standard.object(forKey: groupModelsKey) as? Bool ?? true
        }
    }

    public static func setGroup(_ group: Group, enabled: Bool) {
        let key: String
        switch group {
        case .conversations: key = groupConversationsKey
        case .memory: key = groupMemoryKey
        case .mcp: key = groupMCPKey
        case .models: key = groupModelsKey
        }
        UserDefaults.standard.set(enabled, forKey: key)
    }

    /// Map a table name to the preference group.
    public static func group(forTableName table: String) -> Group? {
        switch table {
        case "Conversation", "Message", "Attachment":
            return .conversations
        case "Memory":
            return .memory
        case "ModelContextServer":
            return .mcp
        case "CloudModel":
            return .models
        default:
            return nil
        }
    }

    /// Whether the specified table name is allowed to sync according to preferences.
    public static func isTableSyncEnabled(tableName: String) -> Bool {
        guard let group = group(forTableName: tableName) else { return true }
        return isGroupEnabled(group)
    }
}

