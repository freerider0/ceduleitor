import Foundation

public class SubSystem {
    public var constraints: [Constraint] = []
    public var parameters: Set<ObjectIdentifier> = []
    public var parameterRefs: [ParameterRef] = []
    public var parameterIndices: [ObjectIdentifier: Int] = [:]
    
    public init() {}
    
    public func addConstraint(_ constraint: Constraint) {
        constraints.append(constraint)
        print("DEBUG SubSystem: Added constraint, now have \(constraints.count) constraints")
        
        let paramCount = constraint.parameters.count
        print("DEBUG SubSystem: Constraint has \(paramCount) parameters")
        
        for param in constraint.parameters {
            let id = ObjectIdentifier(param)
            if !parameters.contains(id) {
                parameters.insert(id)
                parameterIndices[id] = parameterRefs.count
                parameterRefs.append(param)
                print("DEBUG SubSystem: Added new parameter, total params: \(parameterRefs.count)")
            } else {
                print("DEBUG SubSystem: Parameter already exists")
            }
        }
        print("DEBUG SubSystem: After adding constraint - constraints: \(constraints.count), parameters: \(parameterRefs.count)")
    }
    
    public func removeConstraint(_ constraint: Constraint) {
        if let index = constraints.firstIndex(where: { $0 === constraint }) {
            constraints.remove(at: index)
            rebuildParameterList()
        }
    }
    
    private func rebuildParameterList() {
        parameters.removeAll()
        parameterRefs.removeAll()
        parameterIndices.removeAll()
        
        for constraint in constraints {
            for param in constraint.parameters {
                let id = ObjectIdentifier(param)
                if !parameters.contains(id) {
                    parameters.insert(id)
                    parameterIndices[id] = parameterRefs.count
                    parameterRefs.append(param)
                }
            }
        }
    }
    
    public func getParameterValues() -> [Double] {
        return parameterRefs.map { $0.value }
    }
    
    public func setParameterValues(_ values: [Double]) {
        for (index, value) in values.enumerated() {
            if index < parameterRefs.count {
                parameterRefs[index].value = value
            }
        }
    }
    
    public func computeResiduals() -> [Double] {
        return constraints.map { $0.error() }
    }
    
    public func computeJacobian() -> Matrix {
        let m = constraints.count
        let n = parameterRefs.count
        
        var jacobian = Matrix(rows: m, cols: n)
        
        for (i, constraint) in constraints.enumerated() {
            let gradient = constraint.gradient()
            
            for (j, param) in constraint.parameters.enumerated() {
                let id = ObjectIdentifier(param)
                if let colIndex = parameterIndices[id] {
                    jacobian[i, colIndex] = gradient[j]
                }
            }
        }
        
        return jacobian
    }
    
    public func rescaleConstraints() {
        for constraint in constraints {
            constraint.rescale()
        }
    }
    
    public func getMaxError() -> Double {
        return constraints.map { abs($0.error()) }.max() ?? 0.0
    }
    
    public func getTotalError() -> Double {
        return constraints.map { $0.error() * $0.error() }.reduce(0, +)
    }
    
    public func getDOF() -> Int {
        return parameterRefs.count - constraints.count
    }
    
    public func isEmpty() -> Bool {
        return constraints.isEmpty
    }
    
    public func clear() {
        constraints.removeAll()
        parameters.removeAll()
        parameterRefs.removeAll()
        parameterIndices.removeAll()
    }
}