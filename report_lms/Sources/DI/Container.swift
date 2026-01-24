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
        // Auth
        register(AuthServiceType.self) { AuthService() }
        register(AuthRepositoryType.self) { AuthRepository(service: Container.shared.resolve(AuthServiceType.self)!) }
        register(LoginUseCase.self) { LoginUseCase(repository: Container.shared.resolve(AuthRepositoryType.self)!) }
        
        // Inspection
        register(InspectionServiceType.self) { InspectionService() }
        register(InspectionRepositoryType.self) { InspectionRepository(service: Container.shared.resolve(InspectionServiceType.self)!) }
        register(CreateInspectionUseCase.self) { CreateInspectionUseCase(repository: Container.shared.resolve(InspectionRepositoryType.self)!) }
    }
}