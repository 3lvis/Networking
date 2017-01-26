import UIKit

class FakeImageController: UIViewController {
    lazy var imageView: UIImageView = {
        let view = UIImageView(frame: self.view.frame)
        view.contentMode = .scaleAspectFit

        return view
    }()

    lazy var networking: Networking = {
        let networking = Networking(baseURL: "http://httpbin.org")

        let image = UIImage(named: "pig.png")
        networking.fakeImageDownload("/pig", image: image)

        return networking
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .white
        self.view.addSubview(self.imageView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.networking.downloadImage("/pig") { image, _ in
            self.imageView.image = image
        }
    }
}
