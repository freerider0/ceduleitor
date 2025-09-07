import Foundation

public enum Algorithm {
    case bfgs
    case levenbergMarquardt
    case dogLeg
}

public enum SolveStatus {
    case success
    case convergedToLocalMinimum
    case notConverged
    case failed
}

public struct SolverParameters {
    public var algorithm: Algorithm = .dogLeg
    public var maxIterations: Int = 100
    public var convergenceTolerance: Double = 1e-10
    public var bfgsOptions: BFGSSolver.Options = BFGSSolver.Options()
    public var lmOptions: LevenbergMarquardtSolver.Options = LevenbergMarquardtSolver.Options()
    public var dogLegOptions: DogLegSolver.Options = DogLegSolver.Options()
    public var rescaleConstraints: Bool = true
    public var debugMode: Bool = false
    
    public init() {}
}

public class System {
    private var subSystems: [SubSystem] = []
    private var allConstraints: [Constraint] = []
    private var parameters: SolverParameters = SolverParameters()
    private var lastSolveStatus: SolveStatus = .notConverged
    private var lastIterations: Int = 0
    private var lastError: Double = 0.0
    
    public init() {
        subSystems.append(SubSystem())
    }
    
    public func addConstraint(_ constraint: Constraint) {
        allConstraints.append(constraint)
        subSystems[0].addConstraint(constraint)
    }
    
    public func removeConstraint(_ constraint: Constraint) {
        if let index = allConstraints.firstIndex(where: { $0 === constraint }) {
            allConstraints.remove(at: index)
            for subSystem in subSystems {
                subSystem.removeConstraint(constraint)
            }
        }
    }
    
    public func clearConstraints() {
        allConstraints.removeAll()
        for subSystem in subSystems {
            subSystem.clear()
        }
    }
    
    public func setParameters(_ params: SolverParameters) {
        self.parameters = params
    }
    
    public func solve() -> SolveStatus {
        if allConstraints.isEmpty {
            lastSolveStatus = .success
            lastIterations = 0
            lastError = 0.0
            return .success
        }
        
        if parameters.rescaleConstraints {
            for constraint in allConstraints {
                constraint.rescale()
            }
        }
        
        var totalIterations = 0
        var allConverged = true
        
        for subSystem in subSystems where !subSystem.isEmpty() {
            let (status, iterations) = solveSubSystem(subSystem)
            totalIterations += iterations
            
            if status != .success {
                allConverged = false
                if status == .failed {
                    lastSolveStatus = .failed
                    lastIterations = totalIterations
                    lastError = getMaxError()
                    return .failed
                }
            }
        }
        
        lastIterations = totalIterations
        lastError = getMaxError()
        
        if allConverged {
            lastSolveStatus = .success
            return .success
        } else if lastError < parameters.convergenceTolerance * 10 {
            lastSolveStatus = .convergedToLocalMinimum
            return .convergedToLocalMinimum
        } else {
            lastSolveStatus = .notConverged
            return .notConverged
        }
    }
    
    private func solveSubSystem(_ subSystem: SubSystem) -> (status: SolveStatus, iterations: Int) {
        let initialParams = subSystem.getParameterValues()
        
        let residuals: ([Double]) -> [Double] = { params in
            subSystem.setParameterValues(params)
            return subSystem.computeResiduals()
        }
        
        let jacobian: ([Double]) -> Matrix = { params in
            subSystem.setParameterValues(params)
            return subSystem.computeJacobian()
        }
        
        let result: (params: [Double], converged: Bool, iterations: Int)
        
        switch parameters.algorithm {
        case .bfgs:
            let solver = BFGSSolver(dimension: initialParams.count, options: parameters.bfgsOptions)
            
            let objective: ([Double]) -> Double = { params in
                subSystem.setParameterValues(params)
                return subSystem.getTotalError()
            }
            
            let gradient: ([Double]) -> [Double] = { params in
                subSystem.setParameterValues(params)
                let J = subSystem.computeJacobian()
                let r = subSystem.computeResiduals()
                
                var grad = Array(repeating: 0.0, count: params.count)
                for i in 0..<params.count {
                    for j in 0..<r.count {
                        grad[i] += 2 * J[j, i] * r[j]
                    }
                }
                return grad
            }
            
            result = solver.solve(
                initialParams: initialParams,
                objective: objective,
                gradient: gradient
            )
            
        case .levenbergMarquardt:
            let solver = LevenbergMarquardtSolver(options: parameters.lmOptions)
            result = solver.solve(
                initialParams: initialParams,
                residuals: residuals,
                jacobian: jacobian
            )
            
        case .dogLeg:
            let solver = DogLegSolver(options: parameters.dogLegOptions)
            result = solver.solve(
                initialParams: initialParams,
                residuals: residuals,
                jacobian: jacobian
            )
        }
        
        subSystem.setParameterValues(result.params)
        
        if result.converged {
            return (.success, result.iterations)
        } else if subSystem.getMaxError() < parameters.convergenceTolerance * 10 {
            return (.convergedToLocalMinimum, result.iterations)
        } else {
            return (.notConverged, result.iterations)
        }
    }
    
    public func getMaxError() -> Double {
        return subSystems.map { $0.getMaxError() }.max() ?? 0.0
    }
    
    public func getTotalError() -> Double {
        return subSystems.map { $0.getTotalError() }.reduce(0, +)
    }
    
    public func getLastSolveStatus() -> SolveStatus {
        return lastSolveStatus
    }
    
    public func getLastIterations() -> Int {
        return lastIterations
    }
    
    public func getLastError() -> Double {
        return lastError
    }
    
    public func getDOF() -> Int {
        return subSystems.map { $0.getDOF() }.reduce(0, +)
    }
    
    public func partitionConstraints() {
        subSystems.removeAll()
        
        if allConstraints.isEmpty {
            subSystems.append(SubSystem())
            return
        }
        
        var parameterToConstraints: [ObjectIdentifier: [Constraint]] = [:]
        
        for constraint in allConstraints {
            for param in constraint.parameters {
                let id = ObjectIdentifier(param)
                if parameterToConstraints[id] == nil {
                    parameterToConstraints[id] = []
                }
                parameterToConstraints[id]?.append(constraint)
            }
        }
        
        var visited = Set<ObjectIdentifier>()
        var constraintVisited = Set<ObjectIdentifier>()
        
        for constraint in allConstraints {
            let constraintId = ObjectIdentifier(constraint)
            if constraintVisited.contains(constraintId) {
                continue
            }
            
            let subSystem = SubSystem()
            var queue = [constraint]
            
            while !queue.isEmpty {
                let currentConstraint = queue.removeFirst()
                let currentConstraintId = ObjectIdentifier(currentConstraint)
                
                if constraintVisited.contains(currentConstraintId) {
                    continue
                }
                
                constraintVisited.insert(currentConstraintId)
                subSystem.addConstraint(currentConstraint)
                
                for param in currentConstraint.parameters {
                    let paramId = ObjectIdentifier(param)
                    if !visited.contains(paramId) {
                        visited.insert(paramId)
                        
                        if let relatedConstraints = parameterToConstraints[paramId] {
                            for relatedConstraint in relatedConstraints {
                                let relatedId = ObjectIdentifier(relatedConstraint)
                                if !constraintVisited.contains(relatedId) {
                                    queue.append(relatedConstraint)
                                }
                            }
                        }
                    }
                }
            }
            
            subSystems.append(subSystem)
        }
        
        if subSystems.isEmpty {
            subSystems.append(SubSystem())
        }
    }
    
    public func getSubSystemCount() -> Int {
        return subSystems.count
    }
}