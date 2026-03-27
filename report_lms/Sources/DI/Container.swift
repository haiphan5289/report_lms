//
//  Container.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation

final class Container {
    static let shared = Container()

    private var services: [String: Any] = [:]
    private var singletons: [String: Any] = [:]

    private init() {
        registerDependencies()
    }

    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        services[key] = factory
    }

    func registerSingleton<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        singletons[key] = instance
    }

    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)

        // Check singletons first
        if let singleton = singletons[key] as? T {
            return singleton
        }

        // Then check factories
        guard let factory = services[key] as? () -> T else { return nil }
        return factory()
    }

    private func registerDependencies() {
        // Firebase Services - Singleton
        let firebaseAuthService = AuthService()
        registerSingleton(AuthServiceType.self, instance: firebaseAuthService)

        let firebaseStorageService = FirebaseStorageService()
        registerSingleton(FirebaseStorageService.self, instance: firebaseStorageService)

        let firestoreService = FirestoreService()
        registerSingleton(FirestoreService.self, instance: firestoreService)

        // Legacy Services - Singleton to maintain state
        let inspectionService = InspectionService()
        registerSingleton(InspectionServiceType.self, instance: inspectionService)
        
        // Firestore-backed storage service - Singleton for in-memory cache
        let inspectionStorageService = FirestoreInspectionStorageService(firestoreService: firestoreService)
        registerSingleton(InspectionStorageServiceType.self, instance: inspectionStorageService)

        // Repositories - Singleton to maintain publisher state
        let authRepository = AuthRepository(service: firebaseAuthService)
        registerSingleton(AuthRepositoryType.self, instance: authRepository)

        let storageRepository = FirebaseStorageRepository(service: firebaseStorageService)
        registerSingleton(StorageRepositoryType.self, instance: storageRepository)

        let databaseRepository = FirestoreRepository(service: firestoreService)
        registerSingleton(DatabaseRepositoryType.self, instance: databaseRepository)

        let inspectionRepository = InspectionRepository(
            service: inspectionService
        )
        registerSingleton(InspectionRepositoryType.self, instance: inspectionRepository)
        
        // PDF Generator Service - Singleton
        // Using PDFKit native approach (Solution 3) for best performance and quality
        let pdfGeneratorService = PDFKitGeneratorService()
        registerSingleton(PDFGeneratorType.self, instance: pdfGeneratorService)

        // Use Cases - Can be transient since they're stateless
        register(CreateInspectionUseCase.self) {
            CreateInspectionUseCase(
                repository: Container.shared.resolve(InspectionRepositoryType.self)!
            )
        }

        register(FetchInspectionsUseCase.self) {
            FetchInspectionsUseCase(
                repository: Container.shared.resolve(InspectionRepositoryType.self)!
            )
        }

        register(GroupInspectionsByWeekUseCase.self) {
            GroupInspectionsByWeekUseCase()
        }

        register(LoginUseCase.self) {
            LoginUseCase(repository: Container.shared.resolve(AuthRepositoryType.self)!)
        }

        register(UploadInspectionMediaUseCase.self) {
            UploadInspectionMediaUseCase(storageRepository: Container.shared.resolve(StorageRepositoryType.self)!)
        }

        register(SyncInspectionsUseCase.self) {
            SyncInspectionsUseCase(databaseRepository: Container.shared.resolve(DatabaseRepositoryType.self)!)
        }
        
        register(GenerateHTMLPDFReportUseCase.self) {
            guard let pdfGenerator = Container.shared.resolve(PDFGeneratorType.self) else {
                fatalError("PDFGeneratorType must be registered before GenerateHTMLPDFReportUseCase")
            }
            return GenerateHTMLPDFReportUseCase(pdfGenerator: pdfGenerator)
        }

        // UserManager - Singleton for shared state management
        let userManager = UserManager()
        registerSingleton(UserManager.self, instance: userManager)

        // ViewModels - Transient (new instance each time)
        register(LoginViewModel.self) {
            LoginViewModel(
                loginUseCase: Container.shared.resolve(LoginUseCase.self)!,
                userManager: Container.shared.resolve(UserManager.self)!
            )
        }
        register(LMSHomeViewModel.self) {
            LMSHomeViewModel()
        }
        register(OrdersViewModel.self) {
            OrdersViewModel(firestoreService: Container.shared.resolve(FirestoreService.self)!)
        }
        register(PlanLMSHomeViewModel.self) {
            PlanLMSHomeViewModel(
                storageService: Container.shared.resolve(InspectionStorageServiceType.self)!,
                groupInspectionsByWeekUseCase: Container.shared.resolve(GroupInspectionsByWeekUseCase.self)!
            )
        }
    }
}
