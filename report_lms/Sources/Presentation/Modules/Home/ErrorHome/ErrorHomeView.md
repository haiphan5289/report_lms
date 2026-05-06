# ErrorHomeView

Tab "Lỗi" trong `InspectionDetailView` — quản lý danh sách lỗi (error items) của một phiếu kiểm tra.

## Cấu trúc file

```
ErrorHome/
├── ErrorHomeView.swift                        — List UI + FAB + navigation wiring
├── ErrorHomeViewModel.swift                   — State list, thumbnailCache, upsert/delete
├── ErrorHome_workflow.md                      — Luồng chi tiết từng action (CRUD)
├── ErrorHomeView.md                           — Tài liệu này
└── PhotoCaptureErrorReview/
     ├── PhotoCaptureErrorReviewView.swift      — Form chụp/chỉnh sửa lỗi
     └── PhotoCaptureErrorReviewViewModel.swift — State form + save/update logic
```

## Kiến trúc

```
ErrorHomeView (@StateObject ErrorHomeViewModel)
│
├── contentView          — trạng thái: loading / error / empty / list
│    └── inspectionListView  → NavigationLink(value: SavedErrorItem) → edit flow
│
└── floatingButton (FAB) → showErrorCamera = true
     └── CameraView(source: .errorReport)
          └── capturedImages → showErrorReview = true
               └── sheet: PhotoCaptureErrorReviewView (create flow)
```

## States của contentView

| Điều kiện | View hiển thị |
|---|---|
| `isLoading && list rỗng` | `LMSLoadingView()` |
| `errorMessage != nil` | Error view + nút "Thử lại" |
| `errorInspections.isEmpty` | Empty state (checkmark.circle xanh lá) |
| Có data | `inspectionListView` — `LazyVStack` + `ScrollViewReader` |

## Floating Action Button (FAB)

```swift
// Vị trí: ZStack(alignment: .bottomTrailing) bao ngoài contentView
Button { showErrorCamera = true }
  └── CameraView(source: .errorReport)
       └── onPhotoCaptured: [UIImage]
            ├── capturedImages = images
            └── showErrorReview = true → sheet PhotoCaptureErrorReviewView
```

**Lưu ý:** FAB luôn visible ở tất cả states (kể cả loading/error/empty).  
→ Khác với `InspectionDetailContentView` nơi FAB chỉ hiện khi có data.

## Luồng Add New Error (FAB → Save)

```
FAB tap
  └── CameraView → onPhotoCaptured([UIImage])
       └── sheet: PhotoCaptureErrorReviewView(
                initialImages: .local(image:),
                onSaved: { saved, images in
                    viewModel.upsertErrorItem(saved, thumbnails: images)
                    scrollToTopTrigger.toggle()   ← scroll list về đầu
                }
              )
            └── PhotoCaptureErrorReviewViewModel.saveReview()
                 └── errorRepository.saveErrorItem() → Firestore + Storage upload
                      └── returns SavedErrorItem với real imageURLs
```

## Luồng Edit Error (tap item card)

```
NavigationLink(value: item) tap
  └── .navigationDestination(for: SavedErrorItem.self)
       └── PhotoCaptureErrorReviewView(editingItem: item, ...)
            ├── isEditMode = true → hiện "Xoá" / "Lưu Thay đổi" thay vì "Hoàn thành"
            └── onSaved / onDeleted callbacks → upsertErrorItem / deleteErrorItem
```

## Thumbnail Cache Strategy

```
thumbnailCache: [String: UIImage]   ← keyed by item.id, stored in ViewModel

Khi save/edit:   thumbnailCache[item.id] = localImages.first  (instant, không cần AsyncImage)
Khi load list:   AsyncImage(url: imageURLs.first)              (remote items)
Khi delete:      thumbnailCache.removeValue(forKey: id)
```

## Delete Flow (Optimistic)

```
onDeleted(item)
  ├── removeErrorItem(id:)       ← UI update ngay lập tức
  └── Task: errorRepository.deleteErrorItem()
       └── on failure → loadErrorInspections()   ← re-fetch, restore item
```

## Scroll-to-top Trigger

`scrollToTopTrigger: Bool` toggle sau mỗi save/upsert → `ScrollViewReader` watch `onChange` → scroll về `"errorList-top"` anchor với animation.

## Dependencies

| Symbol | Nguồn | Mục đích |
|---|---|---|
| `ErrorRepositoryType` | DI Container | Fetch/save/delete error items (Firestore) |
| `CameraView` | Shared | Chụp ảnh lỗi |
| `PhotoCaptureErrorReviewView` | ErrorHome/ | Form review + save |
| `ErrorItemCardView` | ErrorHome/ | Card item trong list |
| `SavedErrorItem` | Domain/Entities | Model lỗi |
| `ImageSource` | Domain/Entities | `.local(UIImage)` / `.remote(url:)` |

## Known Issues

- [ ] FAB hiển thị cả khi `isLoading` — có thể user tap khi data chưa ready
- [ ] `errorView` retry button dùng external `.frame` thay vì `LMSButton(isFullWidth:)`
- [ ] `saveError` / `fetchErrors` trong protocol là dead code (legacy, unused)
- [ ] `ErrorHomeView` tạo fresh `ErrorHomeViewModel` mỗi lần switch tab → mất state cũ, re-fetch từ Firestore
