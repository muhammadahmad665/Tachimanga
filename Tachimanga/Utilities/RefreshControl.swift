import SwiftUI
import UIKit

class RefreshControlCoordinator: NSObject, ObservableObject {
    var refreshControl = UIRefreshControl()
    var action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
        super.init()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
    }
    
    @objc func handleRefresh() {
        action()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.refreshControl.endRefreshing()
        }
    }
}

struct RefreshControl: UIViewRepresentable {
    let coordinator: RefreshControlCoordinator
    
    func makeUIView(context: Context) -> UIView {
        return UIView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let scrollView = uiView.superview?.superview as? UIScrollView {
            if scrollView.refreshControl == nil {
                scrollView.refreshControl = coordinator.refreshControl
            }
        }
    }
}
