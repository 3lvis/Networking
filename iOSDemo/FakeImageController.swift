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

        view.backgroundColor = .white
        view.addSubview(imageView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        networking.downloadImage("/pig") { image, _ in
            self.imageView.image = image
        }
    }
}
