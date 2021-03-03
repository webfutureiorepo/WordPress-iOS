import UIKit

class ReaderRelatedPostsSectionHeaderView: UITableViewHeaderFooterView, NibReusable {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backgroundColorView: UIView!

    static let height: CGFloat = 40

    override func awakeFromNib() {
        super.awakeFromNib()
        applyStyles()    }

    private func applyStyles() {
        titleLabel.numberOfLines = 0
        titleLabel.font = WPStyleGuide.fontForTextStyle(.subheadline)
        titleLabel.textColor = .text

        backgroundColorView.backgroundColor = .basicBackground
    }

}
