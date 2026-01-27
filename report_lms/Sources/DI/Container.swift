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
    
    private init() {
        registerDependencies()
    }
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        services[key] = factory
    }
    
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        guard let factory = services[key] as? () -> T else { return nil }
        return factory()
    }
    
    private func registerDependencies() {
        // Services
        register(InspectionServiceType.self) { 
            InspectionService() 
        }
        
        // Repositories
        register(InspectionRepositoryType.self) { 
            InspectionRepository(
                service: Container.shared.resolve(InspectionServiceType.self)!
            ) 
        }
        
        // Use Cases
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
        
        // ViewModels
        register(PlanLMSHomeViewModel.self) {
            PlanLMSHomeViewModel(
                fetchInspectionsUseCase: Container.shared.resolve(FetchInspectionsUseCase.self)!,
                groupInspectionsByWeekUseCase: Container.shared.resolve(GroupInspectionsByWeekUseCase.self)!,
                repository: Container.shared.resolve(InspectionRepositoryType.self)!
            )
        }
    }
}