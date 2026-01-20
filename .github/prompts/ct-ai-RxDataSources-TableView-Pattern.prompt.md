# RxDataSources TableView Multiple Sections Pattern

## Overview
Standardized pattern for implementing TableView with multiple sections using RxDataSources and RxSwift.

## Required Imports
```swift
import UIKit
import RxCocoa
import RxSwift
import RxDataSources
```

## 1. CellType Enum Definition
```swift
enum CellType {
    case section1(Model1)
    case section2([Model2])
    case section3(Model3)
    // Add more cases as needed
}
```

## 2. Core Properties Declaration
```swift
// Private variable
typealias Section = SectionModel<String, CellType>
typealias DataSource = RxTableViewSectionedReloadDataSource<Section>
private lazy var dataSource = initDataSource()
private let sources: BehaviorRelay<[Section]> = BehaviorRelay(value: [])

private let disposeBag = DisposeBag()
@IBOutlet private weak var tableView: UITableView!
```

## 3. DataSource Initialization
```swift
private func initDataSource() -> DataSource {
    return DataSource { [weak self] (_, tableView, indexPath, cellType) in
        guard let self = self else { return UITableViewCell() }
        
        switch cellType {
        case .section1(let model):
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Section1Cell")
            cell.textLabel?.text = model.title
            cell.detailTextLabel?.text = model.description
            cell.accessoryType = .disclosureIndicator
            return cell
            
        case .section2(let models):
            let cell = UITableViewCell(style: .default, reuseIdentifier: "Section2Cell")
            cell.textLabel?.text = "\(models.count) items"
            cell.accessoryType = .disclosureIndicator
            return cell
            
        case .section3(let model):
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Section3Cell")
            cell.textLabel?.text = model.name
            cell.detailTextLabel?.text = model.info
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
}
```

## 4. Presenter Configuration
```swift
private func configurePresenter() {
    sources
        .asDriverOnErrorJustComplete()
        .drive(tableView.rx.items(dataSource: dataSource))
        .disposed(by: disposeBag)
    
    // Bind data source
    dataRelay
        .compactMap { $0 }
        .asDriverOnErrorJustComplete()
        .drive { [weak self] data in
            guard let self = self else { return }
            self.setupSections(with: data)
        }
        .disposed(by: disposeBag)
}
```

## 5. Cell Selection Handling
```swift
private func configureListener() {
    tableView.rx.itemSelected
        .asDriver()
        .drive { [weak self] indexPath in
            guard let self = self,
                  let section = self.sources.value.safe[indexPath.section],
                  let cellType = section.items.safe[indexPath.row] else { return }
            
            self.tableView.deselectRow(at: indexPath, animated: true)
            self.handleCellSelection(cellType: cellType)
        }
        .disposed(by: disposeBag)
}

private func handleCellSelection(cellType: CellType) {
    switch cellType {
    case .section1(let model):
        // Handle section1 tap
        break
    case .section2(let models):
        // Handle section2 tap
        break
    case .section3(let model):
        // Handle section3 tap
        break
    }
}
```

## 6. Section Setup
```swift
private func setupSections(with data: DataModel) {
    var sections: [Section] = []
    
    // Section 1
    if let model1 = data.model1 {
        let section1 = Section(model: "section1", items: [.section1(model1)])
        sections.append(section1)
    }
    
    // Section 2
    if !data.model2Array.isEmpty {
        let section2 = Section(model: "section2", items: [.section2(data.model2Array)])
        sections.append(section2)
    }
    
    // Section 3 (Multiple items)
    for item in data.model3Array {
        let section3 = Section(model: "section3", items: [.section3(item)])
        sections.append(section3)
    }
    
    sources.accept(sections)
}
```

## 7. TableView Delegate (Optional)
```swift
// MARK: - UITableViewDelegate
extension YourViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}
```

## Usage Template

### Step 1: Copy Core Properties
```swift
typealias Section = SectionModel<String, CellType>
typealias DataSource = RxTableViewSectionedReloadDataSource<Section>
private lazy var dataSource = initDataSource()
private let sources: BehaviorRelay<[Section]> = BehaviorRelay(value: [])
```

### Step 2: Define Your CellType Enum
```swift
enum CellType {
    case yourSection1(YourModel1)
    case yourSection2([YourModel2])
    // Add more cases...
}
```

### Step 3: Copy and Modify Methods
- `initDataSource()` - Update switch cases for your cell types
- `setupSections()` - Update logic for your data model
- `handleCellSelection()` - Add your selection logic
- `configurePresenter()` - Copy as-is
- `configureListener()` - Copy as-is

### Step 4: Configure in viewDidLoad
```swift
override func viewDidLoad() {
    super.viewDidLoad()
    configurePresenter()
    configureListener()
}
```

## Key Benefits
- ✅ Type-safe section management
- ✅ Reactive data binding
- ✅ Automatic UI updates
- ✅ Clean separation of concerns
- ✅ Easy to extend with new sections
- ✅ Memory efficient with proper disposal

## Notes
- Always use `[weak self]` in closures to prevent retain cycles
- Use `disposed(by: disposeBag)` for all subscriptions
- Use `asDriverOnErrorJustComplete()` for UI binding
- Handle empty states in `setupSections()`