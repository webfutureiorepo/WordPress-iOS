import Foundation
import UIKit
import WordPressKit


/// Convenience class that manages the data and display logic for likes.
/// This is intended to be used as replacement for table view delegate and data source.
class LikesListController: NSObject {

    private let formatter = FormattableContentFormatter()

    private let dependency: LikesListDependency

    private let content: ContentIdentifier

    private let siteID: NSNumber

    private let notification: Notification?

    private let tableView: UITableView

    private var likingUsers: [RemoteUser] = []

    private weak var delegate: LikesListControllerDelegate?

    private var isLoadingContent: Bool = false {
        didSet {
            isLoadingContent ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
            tableView.reloadData()
        }
    }

    private var isShowingError: Bool = false

    // MARK: Views

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    private lazy var loadingCell: UITableViewCell = {
        let cell = UITableViewCell()

        cell.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.safeCenterXAnchor.constraint(equalTo: cell.safeCenterXAnchor),
            activityIndicator.safeCenterYAnchor.constraint(equalTo: cell.safeCenterYAnchor)
        ])

        return cell
    }()

    /**
     TODO: Update this once we get more updates from the design?

     If showing a full-sized, no results page is preferred (e.g. NoResultsViewController),
     then the LikesListDelegate needs to be extended so the delegate can show the no results
     page instead.

     Another alternative is to revert back to the locally available data from the Notification
     object. Although I'm not sure if this would confuse the user since the data would look
     inconsistent between network states.
     */
    private lazy var errorCell: UITableViewCell = {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)

        cell.textLabel?.attributedText = NSAttributedString(string: Constants.errorTitleText,
                                                            attributes: WPStyleGuide.Notifications.footerRegularStyle)

        cell.detailTextLabel?.attributedText = NSAttributedString(string: Constants.errorSubtitleText,
                                                                  attributes: WPStyleGuide.Notifications.footerRegularStyle)

        return cell
    }()

    // MARK: Lifecycle

    init?(tableView: UITableView,
          notification: Notification,
          delegate: LikesListControllerDelegate? = nil,
          dependency: LikesListDependency = LikesListDependency()) {
        guard let siteID = notification.metaSiteID else {
            return nil
        }

        switch notification.kind {
        case .like:
            // post likes
            guard let postID = notification.metaPostID else {
                return nil
            }
            content = .post(id: postID)

        case .commentLike:
            // comment likes
            guard let commentID = notification.metaCommentID else {
                return nil
            }
            content = .comment(id: commentID)

        default:
            // other notification kinds are not supported
            return nil
        }

        self.notification = notification
        self.siteID = siteID
        self.tableView = tableView
        self.dependency = dependency
        self.delegate = delegate
    }

    // MARK: Methods

    /// Load likes data from remote, and display it in the table view.
    func refresh() {
        guard !isLoadingContent else {
            return
        }

        // shows the loading cell and prevents double refresh.
        isShowingError = false
        isLoadingContent = true

        fetchLikes(success: { [weak self] users in
            self?.likingUsers = users ?? []
            self?.isLoadingContent = false
        }, failure: { [weak self] _ in
            self?.isShowingError = true
            self?.isLoadingContent = false
        })
    }

    /// Convenient method that fetches likes data depending on the notification's content type.
    /// - Parameters:
    ///   - success: Closure to be called when the fetch is successful.
    ///   - failure: Closure to be called when the fetch failed.
    private func fetchLikes(success: @escaping ([RemoteUser]?) -> Void, failure: @escaping (Error?) -> Void) {
        switch content {
        case .post(let postID):
            dependency.postService.getLikesForPostID(postID,
                                                     siteID: siteID,
                                                     success: success,
                                                     failure: failure)
        case .comment(let commentID):
            dependency.commentService.getLikesForCommentID(commentID,
                                                           siteID: siteID,
                                                           success: success,
                                                           failure: failure)
        }
    }
}

// MARK: - Table View Related

extension LikesListController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Constants.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // header section
        if section == Constants.headerSectionIndex {
            return Constants.numberOfHeaderRows
        }

        if isLoadingContent {
            return Constants.numberOfLoadingRows
        }

        if isShowingError {
            return Constants.numberOfErrorRows
        }

        // users section
        return likingUsers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == Constants.headerSectionIndex {
            return headerCell()
        }

        if isLoadingContent {
            return loadingCell
        }

        if isShowingError {
            return errorCell
        }

        return userCell(for: indexPath)
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return Constants.estimatedRowHeight
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == Constants.headerSectionIndex {
            delegate?.didSelectHeader()
            return
        }

        guard !isLoadingContent,
              !isShowingError,
              indexPath.row < likingUsers.count else {
            return
        }

        delegate?.didSelectUser(likingUsers[indexPath.row])
    }

}

// MARK: - Notification Cell Handling

private extension LikesListController {

    func headerCell() -> NoteBlockHeaderTableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: NoteBlockHeaderTableViewCell.reuseIdentifier()) as? NoteBlockHeaderTableViewCell,
              let group = notification?.headerAndBodyContentGroups[Constants.headerRowIndex] else {
            DDLogError("Error: couldn't get a header cell or FormattableContentGroup.")
            return NoteBlockHeaderTableViewCell()
        }

        setupHeaderCell(cell: cell, group: group)
        return cell
    }

    func setupHeaderCell(cell: NoteBlockHeaderTableViewCell, group: FormattableContentGroup) {
        cell.attributedHeaderTitle = nil
        cell.attributedHeaderDetails = nil

        guard let gravatarBlock: NotificationTextContent = group.blockOfKind(.image),
            let snippetBlock: NotificationTextContent = group.blockOfKind(.text) else {
                return
        }

        cell.attributedHeaderTitle = formatter.render(content: gravatarBlock, with: HeaderContentStyles())
        cell.attributedHeaderDetails = formatter.render(content: snippetBlock, with: HeaderDetailsContentStyles())

        // Download the Gravatar
        let mediaURL = gravatarBlock.media.first?.mediaURL
        cell.downloadAuthorAvatar(with: mediaURL)
    }

    func userCell(for indexPath: IndexPath) -> NoteBlockUserTableViewCell {
        guard indexPath.row < likingUsers.count,
              let cell = tableView.dequeueReusableCell(withIdentifier: NoteBlockUserTableViewCell.reuseIdentifier()) as? NoteBlockUserTableViewCell else {
            DDLogError("Error: couldn't get a user cell or requested row is out of boundary")
            return NoteBlockUserTableViewCell()
        }

        let user = likingUsers[indexPath.row]
        cell.accessoryType = .none
        cell.name = user.displayName

        // TODO: Re-enable follow functionality once the information is available.
        cell.isFollowEnabled = false
        cell.isFollowOn = false

        // TODO: Configure blog title once the information is available.
        cell.blogTitle = ""

        if let mediaURL = URL(string: user.avatarURL) {
            cell.downloadGravatarWithURL(mediaURL)
        }

        // configure the ending separator line
        cell.isLastRow = (indexPath.row == likingUsers.count - 1)

        return cell
    }

}

// MARK: - Dependency Definitions

/// A simple, convenient dependency wrapper for LikesListController.
class LikesListDependency {

    private let context: NSManagedObjectContext

    lazy var postService: PostService = {
        PostService(managedObjectContext: self.context)
    }()

    lazy var commentService: CommentService = {
        CommentService(managedObjectContext: self.context)
    }()

    init(context: NSManagedObjectContext = ContextManager.shared.mainContext) {
        self.context = context
    }

}

// MARK: - Delegate Definitions

protocol LikesListControllerDelegate: class {
    /// Reports to the delegate that the header cell has been tapped.
    func didSelectHeader()

    /// Reports to the delegate that the user cell has been tapped.
    /// - Parameter user: A RemoteUser instance representing the user at the selected row.
    func didSelectUser(_ user: RemoteUser)
}

// MARK: - Private Definitions

private extension LikesListController {

    /// Convenient type that categorizes notification content and its ID.
    enum ContentIdentifier {
        case post(id: NSNumber)
        case comment(id: NSNumber)
    }

    enum Constants {
        static let numberOfSections = 2
        static let estimatedRowHeight: CGFloat = 44
        static let headerSectionIndex = 0
        static let headerRowIndex = 0
        static let numberOfHeaderRows = 1
        static let numberOfLoadingRows = 1
        static let numberOfErrorRows = 1

        static let errorTitleText = NSLocalizedString("Unable to load this content right now.", comment: "Informing the user that a network request failed because the device wasn't able to establish a network connection.")
        static let errorSubtitleText = NSLocalizedString("Check your network connection and try again.", comment: "Default subtitle for no-results when there is no connection")
    }

}
