import Foundation

extension MySiteViewController {
    func startObservingOnboardingPrompt() {
        NotificationCenter.default.addObserver(self, selector: #selector(onboardingPromptWasDismissed(_:)), name: .onboardingPromptWasDismissed, object: nil)
    }

    @objc func onboardingPromptWasDismissed(_ notification: NSNotification) {
        guard
            let userInfo = notification.userInfo,
            let option = userInfo["option"] as? OnboardingOption
        else {
            return
        }

        switch option {
        case .stats:
            // Show the stats view for the current blog
            // We have to switch to the "Site Menu" first
            switchTab(to: .siteMenu)

            // Show the stats tab
            blogDetailsViewController?.showStats(from: .button)
        case .writing:
            // Open the editor
            let controller = tabBarController as? WPTabBarController
            controller?.showPostTab(completion: {
                self.startAlertTimer()
            })
        case .notifications:
            // Open the notifications tab
            let controller = tabBarController as? WPTabBarController
            controller?.showNotificationsTab()
        case .reader:
            // Open the reader tab
            let controller = tabBarController as? WPTabBarController
            controller?.showReaderTab()
        case .showMeAround:
            // Start the quick start
            if let blog = blog {
                QuickStartTourGuide.shared.setup(for: blog)
            }
        case .skip:
            // Do nothing
            break
        }
    }
}
