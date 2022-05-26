import Foundation
import CoreData
import WordPressKit

public class BloggingPromptSettings: NSManagedObject {

    func configure(with remoteSettings: RemoteBloggingPromptsSettings, siteID: Int32, context: NSManagedObjectContext) {
        self.siteID = siteID
        self.promptCardEnabled = remoteSettings.promptCardEnabled
        self.reminderTime = remoteSettings.reminderTime
        self.promptRemindersEnabled = remoteSettings.promptRemindersEnabled
        self.isPotentialBloggingSite = remoteSettings.isPotentialBloggingSite
        self.reminderDays = reminderDays ?? BloggingPromptSettingsReminderDays(context: context)
        reminderDays?.configure(with: remoteSettings.reminderDays)
    }

    func reminderTimeDate() -> Date? {
        guard let reminderTime = reminderTime else {
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH.mm"
        return dateFormatter.date(from: reminderTime)
    }

}
