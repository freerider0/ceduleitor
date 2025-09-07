import Foundation

public enum DiagnosticResult {
    case wellConstrained
    case underConstrained(dof: Int)
    case overConstrained(conflicting: [Constraint])
    case redundant(redundant: [Constraint])
}

public class Diagnostics {
    private let system: System
    
    public init(system: System) {
        self.system = system
    }
    
    public func analyze() -> DiagnosticResult {
        let dof = system.getDOF()
        
        if dof > 0 {
            return .underConstrained(dof: dof)
        } else if dof < 0 {
            let conflicting = findConflictingConstraints()
            if !conflicting.isEmpty {
                return .overConstrained(conflicting: conflicting)
            }
            
            let redundant = findRedundantConstraints()
            if !redundant.isEmpty {
                return .redundant(redundant: redundant)
            }
        }
        
        return .wellConstrained
    }
    
    public func findConflictingConstraints() -> [Constraint] {
        var conflicting: [Constraint] = []
        let constraints = getAllConstraints()
        
        for constraint in constraints {
            system.removeConstraint(constraint)
            
            let statusBefore = system.solve()
            system.addConstraint(constraint)
            let statusAfter = system.solve()
            
            if statusBefore == .success && statusAfter != .success {
                conflicting.append(constraint)
            }
        }
        
        return conflicting
    }
    
    public func findRedundantConstraints() -> [Constraint] {
        var redundant: [Constraint] = []
        let constraints = getAllConstraints()
        
        for constraint in constraints {
            let errorBefore = constraint.error()
            
            system.removeConstraint(constraint)
            let status = system.solve()
            
            if status == .success {
                let errorAfter = constraint.error()
                if abs(errorAfter) < 1e-10 {
                    redundant.append(constraint)
                }
            }
            
            system.addConstraint(constraint)
        }
        
        return redundant
    }
    
    public func computeConstraintSensitivity() -> [Constraint: Double] {
        var sensitivities: [Constraint: Double] = [:]
        let constraints = getAllConstraints()
        
        for constraint in constraints {
            let originalScale = constraint.scale
            constraint.scale *= 1.1
            
            system.solve()
            let perturbedError = system.getTotalError()
            
            constraint.scale = originalScale
            system.solve()
            let originalError = system.getTotalError()
            
            let sensitivity = abs(perturbedError - originalError) / (0.1 * originalScale)
            sensitivities[constraint] = sensitivity
        }
        
        return sensitivities
    }
    
    public func computeParameterSensitivity() -> [ParameterRef: Double] {
        var sensitivities: [ParameterRef: Double] = [:]
        let parameters = getAllParameters()
        
        for param in parameters {
            let originalValue = param.value
            param.value *= 1.01
            
            system.solve()
            let perturbedError = system.getTotalError()
            
            param.value = originalValue
            system.solve()
            let originalError = system.getTotalError()
            
            let sensitivity = abs(perturbedError - originalError) / (0.01 * abs(originalValue + 1e-10))
            sensitivities[param] = sensitivity
        }
        
        return sensitivities
    }
    
    public func rankDeficiencyAnalysis() -> Int {
        let subSystems = getSubSystems()
        var totalRankDeficiency = 0
        
        for subSystem in subSystems {
            let jacobian = subSystem.computeJacobian()
            let (_, r) = jacobian.qrDecomposition()
            
            var rank = 0
            let threshold = 1e-10
            
            for i in 0..<min(r.rows, r.cols) {
                if abs(r[i, i]) > threshold {
                    rank += 1
                }
            }
            
            let expectedRank = min(jacobian.rows, jacobian.cols)
            totalRankDeficiency += expectedRank - rank
        }
        
        return totalRankDeficiency
    }
    
    private func getAllConstraints() -> [Constraint] {
        var constraints: [Constraint] = []
        for subSystem in getSubSystems() {
            constraints.append(contentsOf: subSystem.constraints)
        }
        return constraints
    }
    
    private func getAllParameters() -> [ParameterRef] {
        var parameters: [ParameterRef] = []
        var seen = Set<ObjectIdentifier>()
        
        for subSystem in getSubSystems() {
            for param in subSystem.parameterRefs {
                let id = ObjectIdentifier(param)
                if !seen.contains(id) {
                    seen.insert(id)
                    parameters.append(param)
                }
            }
        }
        
        return parameters
    }
    
    private func getSubSystems() -> [SubSystem] {
        let mirror = Mirror(reflecting: system)
        for child in mirror.children {
            if let subSystems = child.value as? [SubSystem] {
                return subSystems
            }
        }
        return []
    }
}

public extension System {
    func diagnose() -> DiagnosticResult {
        let diagnostics = Diagnostics(system: self)
        return diagnostics.analyze()
    }
    
    func findConflictingConstraints() -> [Constraint] {
        let diagnostics = Diagnostics(system: self)
        return diagnostics.findConflictingConstraints()
    }
    
    func findRedundantConstraints() -> [Constraint] {
        let diagnostics = Diagnostics(system: self)
        return diagnostics.findRedundantConstraints()
    }
}