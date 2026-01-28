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
        // Services - Singleton to maintain state
        let inspectionService = InspectionService()
        registerSingleton(InspectionServiceType.self, instance: inspectionService)
        
        // Repositories - Singleton to maintain publisher state
        let inspectionRepository = InspectionRepository(
            service: inspectionService
        )
        registerSingleton(InspectionRepositoryType.self, instance: inspectionRepository)
        
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
        
        // ViewModels - Transient (new instance each time)
        register(PlanLMSHomeViewModel.self) {
            PlanLMSHomeViewModel(
                fetchInspectionsUseCase: Container.shared.resolve(FetchInspectionsUseCase.self)!,
                groupInspectionsByWeekUseCase: Container.shared.resolve(GroupInspectionsByWeekUseCase.self)!,
                repository: Container.shared.resolve(InspectionRepositoryType.self)!
            )
        }
    }
}