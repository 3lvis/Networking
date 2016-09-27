import UIKit

class OptionsController: UITableViewController {
    var cellIdentifier: String {
        return String(describing: UITableViewCell.self)
    }

    lazy var data: [[CellData]] = {
        var data = [[CellData]]()

        var firstSection = [CellData]()

        firstSection.append(CellData(title: "Fake image") {
            let controller = FakeImageController(nibName: nil, bundle: nil)
            self.navigationController?.pushViewController(controller, animated: true)
        })

        data.append(firstSection)

        return data
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: self.cellIdentifier)
    }

    func object(at indexPath: IndexPath) -> CellData {
        let section = self.data[indexPath.section]
        let object = section[indexPath.row]

        return object
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.data.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = self.data[section]

        return section.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellIdentifier, for: indexPath)

        let object = self.object(at: indexPath)
        cell.textLabel?.text = object.title

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let object = self.object(at: indexPath)
        object.action()
    }
}

