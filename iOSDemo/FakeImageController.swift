import UIKit

class FakeImageController: UIViewController {
    lazy var imageView: UIImageView = {
        let view = UIImageView(frame: self.view.frame)
        view.contentMode = .scaleAspectFit

        return view
    }()

    lazy var networking: Networking = {
        let networking = Networking(baseURL: "http://httpbin.org")

        // let image = UIImage(named: "pig.png")
        // networking.fakeImageDownload("/image/png", image: image)

        return networking
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        view.addSubview(imageView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        networking.downloadImage("/image/png") { result in
            switch result {
            case let .success(response):
                self.imageView.image = response.image
            case .failure:
                break
            }
        }
    }
}
