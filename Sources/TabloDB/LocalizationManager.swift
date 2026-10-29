// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var displayName: String {
        switch self {
        case .system:
            return localizedStrings[.english]?["settings.language.system"] ?? "System Default"
        case .english:
            return localizedStrings[.english]?["settings.language.english"] ?? "English"
        case .simplifiedChinese:
            return localizedStrings[.simplifiedChinese]?["settings.language.simplifiedChinese"] ?? "简体中文"
        case .traditionalChinese:
            return localizedStrings[.traditionalChinese]?["settings.language.traditionalChinese"] ?? "繁體中文"
        }
    }
}

final class LocalizationManager {
    static let shared = LocalizationManager()

    private let languageKey = "appLanguage"

    var currentLanguage: AppLanguage {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: languageKey),
               let language = AppLanguage(rawValue: rawValue) {
                return language
            }
            return .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }

    private init() {}

    func localizedString(_ key: String) -> String {
        let language = currentLanguage == .system ? systemLanguage() : currentLanguage
        return localizedStrings[language]?[key] ?? key
    }

    func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localizedString(key)
        return String(format: format, arguments)
    }

    private func systemLanguage() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh-CN") {
            return .simplifiedChinese
        } else if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") || preferred.hasPrefix("zh-HK") {
            return .traditionalChinese
        }
        return .english
    }
}

func L(_ key: String) -> String {
    return LocalizationManager.shared.localizedString(key)
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    return LocalizationManager.shared.localizedString(key, arguments)
}

private let localizedStrings: [AppLanguage: [String: String]] = [
    .english: [
        // Settings
        "settings.title": "Settings",
        "settings.tab.general": "General",
        "settings.tab.about": "About",
        "settings.language": "Language:",
        "settings.language.system": "System Default",
        "settings.language.english": "English",
        "settings.language.simplifiedChinese": "Simplified Chinese",
        "settings.language.traditionalChinese": "Traditional Chinese",
        "settings.updateCheck": "Auto Update Check:",
        "settings.updateCheck.now": "Check Now",
        "settings.updateCheck.never": "Never",
        "settings.updateCheck.atStartup": "At Startup",
        "settings.updateCheck.daily": "Daily",
        "settings.updateCheck.weekly": "Weekly",
        "settings.updateCheck.monthly": "Monthly",
        "settings.quitOnClose": "Keep running after close:",
        "settings.logEnabled": "Enable logging:",
        "settings.logPath": "Log path:",
        "settings.about.version": "Version",
        "settings.about.copyright": "Copyright © 2026 Jia Liu",
        "settings.about.description": "A native macOS database GUI supporting multiple data sources.",
        "settings.about.checkUpdates": "Check for Updates",

        // Sidebar
        "sidebar.tables": "Tables",
        "sidebar.search.placeholder": "Search tables...",
        "sidebar.noDatabase": "No database open",
        "sidebar.menu.rename": "Rename Table",
        "sidebar.menu.empty": "Empty Table",
        "sidebar.menu.delete": "Delete Table",
        "sidebar.newTable.title": "Create New Table",
        "sidebar.newTable.message": "Enter table name:",
        "sidebar.newTable.create": "Create",
        "sidebar.newTable.cancel": "Cancel",
        "sidebar.renameTable.title": "Rename Table",
        "sidebar.renameTable.message": "Enter new name for '%@':",
        "sidebar.renameTable.rename": "Rename",
        "sidebar.renameTable.cancel": "Cancel",
        "sidebar.emptyTable.title": "Empty Table",
        "sidebar.emptyTable.message": "Are you sure you want to delete all rows from '%@'? This cannot be undone.",
        "sidebar.emptyTable.empty": "Empty",
        "sidebar.emptyTable.cancel": "Cancel",
        "sidebar.deleteTable.title": "Delete %@",
        "sidebar.deleteTable.message": "Are you sure you want to delete '%@'? This cannot be undone.",
        "sidebar.deleteTable.delete": "Delete",
        "sidebar.deleteTable.cancel": "Cancel",
        "sidebar.error.cannotRenameView": "Cannot rename views",
        "sidebar.error.cannotEmptyView": "Cannot empty views",

        // Tabs
        "tab.data": "Data",
        "tab.sql": "SQL",

        // Table View
        "table.loading": "Loading...",
        "table.noData": "No data",
        "table.error": "Error",
        "table.rowCount": "%d rows",
        "table.page": "Page %d of %d",

        // Overview
        "overview.name": "Name",
        "overview.type": "Type",
        "overview.rows": "Rows",

        // SQL Editor
        "sql.run": "Run",
        "sql.clear": "Clear",
        "sql.placeholder": "Enter SQL query...",
        "sql.result": "Result",
        "sql.noResult": "No results",
        "sql.error": "SQL Error",

        // Menu
        "menu.file": "File",
        "menu.edit": "Edit",
        "menu.view": "View",
        "menu.window": "Window",
        "menu.help": "Help",
        "menu.about": "About %@",
        "menu.preferences": "Preferences...",
        "menu.checkForUpdates": "Check for Updates...",
        "menu.quit": "Quit %@",
        "menu.hide": "Hide %@",
        "menu.hideOthers": "Hide Others",
        "menu.showAll": "Show All",
        "menu.newSQLite": "New SQLite Database...",
        "menu.newDuckDB": "New DuckDB Database...",
        "menu.openCSV": "Open CSV...",
        "menu.openCSVDir": "Open CSV Directory...",
        "menu.openParquet": "Open Parquet...",
        "menu.openParquetDir": "Open Parquet Directory...",
        "menu.open": "Open Database...",
        "menu.close": "Close Database",
        "menu.closeWindow": "Close Window",
        "menu.recent": "Recent Databases",
        "menu.recent.none": "No Recent Databases",
        "menu.recent.clear": "Clear Recent List",
        "menu.export": "Export as CSV...",
        "menu.import": "Import CSV...",
        "menu.moveToTrash": "Move to Trash",
        "menu.refresh": "Refresh",
        "menu.minimize": "Minimize",
        "menu.zoom": "Zoom",
        "menu.bringAllToFront": "Bring All to Front",

        // Dialogs
        "dialog.newSQLite": "New SQLite Database",
        "dialog.newDuckDB": "New DuckDB Database",
        "dialog.openCSV": "Open CSV File",
        "dialog.openCSVDir": "Open CSV Directory",
        "dialog.openParquet": "Open Parquet File",
        "dialog.openParquetDir": "Open Parquet Directory",
        "dialog.pathLabel": "Path:",
        "dialog.pathPlaceholder": "Enter path manually...",
        "dialog.open": "Open Database",
        "dialog.export": "Export as CSV",
        "dialog.import": "Import CSV",
        "dialog.selectDirectory": "Select a directory",

        // Errors
        "error.noDatabase": "No Database",
        "error.noDatabase.message": "Please open a database first.",
        "error.noData": "No Data",
        "error.noData.message": "Please select a table to export.",
        "error.exportFailed": "Export Failed",
        "error.importFailed": "Import Failed",

        // Success
        "success.import": "Import Successful",
        "success.import.message": "Imported %d rows into table '%@'.",

        // Edit
        "edit.confirm.title": "Save Changes?",
        "edit.confirm.message": "Do you want to save this change?",
        "edit.confirm.save": "Save",
        "edit.confirm.cancel": "Cancel",
        "edit.confirm.dontAsk": "Don't ask again",
    ],

    .simplifiedChinese: [
        // Settings
        "settings.title": "设置",
        "settings.tab.general": "通用",
        "settings.tab.about": "关于",
        "settings.language": "语言：",
        "settings.language.system": "系统默认",
        "settings.language.english": "English",
        "settings.language.simplifiedChinese": "简体中文",
        "settings.language.traditionalChinese": "繁體中文",
        "settings.updateCheck": "自动检查更新：",
        "settings.updateCheck.now": "立即检查",
        "settings.updateCheck.never": "从不",
        "settings.updateCheck.atStartup": "每次启动",
        "settings.updateCheck.daily": "每天",
        "settings.updateCheck.weekly": "每周",
        "settings.updateCheck.monthly": "每月",
        "settings.quitOnClose": "关闭窗口不退出：",
        "settings.logEnabled": "启用日志：",
        "settings.logPath": "日志路径：",
        "settings.about.version": "版本",
        "settings.about.copyright": "版权所有 © 2026 Jia Liu",
        "settings.about.description": "原生 macOS 数据库 GUI，支持多种数据源。",
        "settings.about.checkUpdates": "检查更新",

        // Sidebar
        "sidebar.tables": "数据表",
        "sidebar.search.placeholder": "搜索数据表...",
        "sidebar.noDatabase": "未打开数据库",
        "sidebar.menu.rename": "重命名表",
        "sidebar.menu.empty": "清空表",
        "sidebar.menu.delete": "删除表",
        "sidebar.newTable.title": "新建数据表",
        "sidebar.newTable.message": "输入表名：",
        "sidebar.newTable.create": "创建",
        "sidebar.newTable.cancel": "取消",
        "sidebar.renameTable.title": "重命名表",
        "sidebar.renameTable.message": "输入 '%@' 的新名称：",
        "sidebar.renameTable.rename": "重命名",
        "sidebar.renameTable.cancel": "取消",
        "sidebar.emptyTable.title": "清空表",
        "sidebar.emptyTable.message": "确定要删除 '%@' 中的所有行吗？此操作无法撤销。",
        "sidebar.emptyTable.empty": "清空",
        "sidebar.emptyTable.cancel": "取消",
        "sidebar.deleteTable.title": "删除 %@",
        "sidebar.deleteTable.message": "确定要删除 '%@' 吗？此操作无法撤销。",
        "sidebar.deleteTable.delete": "删除",
        "sidebar.deleteTable.cancel": "取消",
        "sidebar.error.cannotRenameView": "无法重命名视图",
        "sidebar.error.cannotEmptyView": "无法清空视图",

        // Tabs
        "tab.data": "数据",
        "tab.sql": "SQL",

        // Table View
        "table.loading": "加载中...",
        "table.noData": "无数据",
        "table.error": "错误",
        "table.rowCount": "%d 行",
        "table.page": "第 %d 页，共 %d 页",

        // Overview
        "overview.name": "名称",
        "overview.type": "类型",
        "overview.rows": "行数",

        // SQL Editor
        "sql.run": "运行",
        "sql.clear": "清空",
        "sql.placeholder": "输入 SQL 查询...",
        "sql.result": "结果",
        "sql.noResult": "无结果",
        "sql.error": "SQL 错误",

        // Menu
        "menu.file": "文件",
        "menu.edit": "编辑",
        "menu.view": "显示",
        "menu.window": "窗口",
        "menu.help": "帮助",
        "menu.about": "关于 %@",
        "menu.preferences": "偏好设置...",
        "menu.checkForUpdates": "检查更新...",
        "menu.quit": "退出 %@",
        "menu.hide": "隐藏 %@",
        "menu.hideOthers": "隐藏其他",
        "menu.showAll": "全部显示",
        "menu.newSQLite": "新建 SQLite 数据库...",
        "menu.newDuckDB": "新建 DuckDB 数据库...",
        "menu.openCSV": "打开 CSV...",
        "menu.openCSVDir": "打开 CSV 目录...",
        "menu.openParquet": "打开 Parquet...",
        "menu.openParquetDir": "打开 Parquet 目录...",
        "menu.open": "打开数据库...",
        "menu.close": "关闭数据库",
        "menu.closeWindow": "关闭窗口",
        "menu.recent": "最近的数据库",
        "menu.recent.none": "无最近的数据库",
        "menu.recent.clear": "清除最近列表",
        "menu.export": "导出为 CSV...",
        "menu.import": "导入 CSV...",
        "menu.moveToTrash": "移至废纸篓",
        "menu.refresh": "刷新",
        "menu.minimize": "最小化",
        "menu.zoom": "缩放",
        "menu.bringAllToFront": "全部移到最前",

        // Dialogs
        "dialog.newSQLite": "新建 SQLite 数据库",
        "dialog.newDuckDB": "新建 DuckDB 数据库",
        "dialog.openCSV": "打开 CSV 文件",
        "dialog.openCSVDir": "打开 CSV 目录",
        "dialog.openParquet": "打开 Parquet 文件",
        "dialog.openParquetDir": "打开 Parquet 目录",
        "dialog.pathLabel": "路径：",
        "dialog.pathPlaceholder": "手动输入路径...",
        "dialog.open": "打开数据库",
        "dialog.export": "导出为 CSV",
        "dialog.import": "导入 CSV",
        "dialog.selectDirectory": "选择目录",

        // Errors
        "error.noDatabase": "无数据库",
        "error.noDatabase.message": "请先打开一个数据库。",
        "error.noData": "无数据",
        "error.noData.message": "请选择要导出的数据表。",
        "error.exportFailed": "导出失败",
        "error.importFailed": "导入失败",

        // Success
        "success.import": "导入成功",
        "success.import.message": "已将 %d 行数据导入到表 '%@'。",

        // Edit
        "edit.confirm.title": "保存更改？",
        "edit.confirm.message": "是否保存此更改？",
        "edit.confirm.save": "保存",
        "edit.confirm.cancel": "取消",
        "edit.confirm.dontAsk": "不再询问",
    ],

    .traditionalChinese: [
        // Settings
        "settings.title": "設定",
        "settings.tab.general": "一般",
        "settings.tab.about": "關於",
        "settings.language": "語言：",
        "settings.language.system": "系統預設",
        "settings.language.english": "English",
        "settings.language.simplifiedChinese": "简体中文",
        "settings.language.traditionalChinese": "繁體中文",
        "settings.updateCheck": "自動檢查更新：",
        "settings.updateCheck.now": "立即檢查",
        "settings.updateCheck.never": "從不",
        "settings.updateCheck.atStartup": "每次啟動",
        "settings.updateCheck.daily": "每天",
        "settings.updateCheck.weekly": "每週",
        "settings.updateCheck.monthly": "每月",
        "settings.quitOnClose": "關閉視窗不結束：",
        "settings.logEnabled": "啟用日誌：",
        "settings.logPath": "日誌路徑：",
        "settings.about.version": "版本",
        "settings.about.copyright": "版權所有 © 2026 Jia Liu",
        "settings.about.description": "原生 macOS 資料庫 GUI，支援多種資料來源。",
        "settings.about.checkUpdates": "檢查更新",

        // Sidebar
        "sidebar.tables": "資料表",
        "sidebar.search.placeholder": "搜尋資料表...",
        "sidebar.noDatabase": "未開啟資料庫",
        "sidebar.menu.rename": "重新命名表格",
        "sidebar.menu.empty": "清空表格",
        "sidebar.menu.delete": "刪除表格",
        "sidebar.newTable.title": "新建資料表",
        "sidebar.newTable.message": "輸入表格名稱：",
        "sidebar.newTable.create": "建立",
        "sidebar.newTable.cancel": "取消",
        "sidebar.renameTable.title": "重新命名表格",
        "sidebar.renameTable.message": "輸入 '%@' 的新名稱：",
        "sidebar.renameTable.rename": "重新命名",
        "sidebar.renameTable.cancel": "取消",
        "sidebar.emptyTable.title": "清空表格",
        "sidebar.emptyTable.message": "確定要刪除 '%@' 中的所有列嗎？此操作無法復原。",
        "sidebar.emptyTable.empty": "清空",
        "sidebar.emptyTable.cancel": "取消",
        "sidebar.deleteTable.title": "刪除 %@",
        "sidebar.deleteTable.message": "確定要刪除 '%@' 嗎？此操作無法復原。",
        "sidebar.deleteTable.delete": "刪除",
        "sidebar.deleteTable.cancel": "取消",
        "sidebar.error.cannotRenameView": "無法重新命名檢視",
        "sidebar.error.cannotEmptyView": "無法清空檢視",

        // Tabs
        "tab.data": "資料",
        "tab.sql": "SQL",

        // Table View
        "table.loading": "載入中...",
        "table.noData": "無資料",
        "table.error": "錯誤",
        "table.rowCount": "%d 列",
        "table.page": "第 %d 頁，共 %d 頁",

        // Overview
        "overview.name": "名稱",
        "overview.type": "類型",
        "overview.rows": "列數",

        // SQL Editor
        "sql.run": "執行",
        "sql.clear": "清除",
        "sql.placeholder": "輸入 SQL 查詢...",
        "sql.result": "結果",
        "sql.noResult": "無結果",
        "sql.error": "SQL 錯誤",

        // Menu
        "menu.file": "檔案",
        "menu.edit": "編輯",
        "menu.view": "顯示",
        "menu.window": "視窗",
        "menu.help": "輔助說明",
        "menu.about": "關於 %@",
        "menu.preferences": "偏好設定...",
        "menu.checkForUpdates": "檢查更新...",
        "menu.quit": "結束 %@",
        "menu.hide": "隱藏 %@",
        "menu.hideOthers": "隱藏其他",
        "menu.showAll": "全部顯示",
        "menu.newSQLite": "新建 SQLite 資料庫...",
        "menu.newDuckDB": "新建 DuckDB 資料庫...",
        "menu.openCSV": "開啟 CSV...",
        "menu.openCSVDir": "開啟 CSV 目錄...",
        "menu.openParquet": "開啟 Parquet...",
        "menu.openParquetDir": "開啟 Parquet 目錄...",
        "menu.open": "開啟資料庫...",
        "menu.close": "關閉資料庫",
        "menu.closeWindow": "關閉視窗",
        "menu.recent": "最近的資料庫",
        "menu.recent.none": "無最近的資料庫",
        "menu.recent.clear": "清除最近列表",
        "menu.export": "匯出為 CSV...",
        "menu.import": "匯入 CSV...",
        "menu.moveToTrash": "移至垃圾桶",
        "menu.refresh": "重新整理",
        "menu.minimize": "最小化",
        "menu.zoom": "縮放",
        "menu.bringAllToFront": "全部移到最前",

        // Dialogs
        "dialog.newSQLite": "新建 SQLite 資料庫",
        "dialog.newDuckDB": "新建 DuckDB 資料庫",
        "dialog.openCSV": "開啟 CSV 檔案",
        "dialog.openCSVDir": "開啟 CSV 目錄",
        "dialog.openParquet": "開啟 Parquet 檔案",
        "dialog.openParquetDir": "開啟 Parquet 目錄",
        "dialog.pathLabel": "路徑：",
        "dialog.pathPlaceholder": "手動輸入路徑...",
        "dialog.open": "開啟資料庫",
        "dialog.export": "匯出為 CSV",
        "dialog.import": "匯入 CSV",
        "dialog.selectDirectory": "選擇目錄",

        // Errors
        "error.noDatabase": "無資料庫",
        "error.noDatabase.message": "請先開啟一個資料庫。",
        "error.noData": "無資料",
        "error.noData.message": "請選擇要匯出的資料表。",
        "error.exportFailed": "匯出失敗",
        "error.importFailed": "匯入失敗",

        // Success
        "success.import": "匯入成功",
        "success.import.message": "已將 %d 列資料匯入到表 '%@'。",

        // Edit
        "edit.confirm.title": "儲存變更？",
        "edit.confirm.message": "是否儲存此變更？",
        "edit.confirm.save": "儲存",
        "edit.confirm.cancel": "取消",
        "edit.confirm.dontAsk": "不再詢問",
    ]
]
