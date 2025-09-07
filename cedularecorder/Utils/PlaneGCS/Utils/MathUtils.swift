import Foundation
import Accelerate

// Define LAPACK type alias for iOS compatibility
typealias __LAPACK_int = __CLPK_integer

public typealias Parameter = Double

public struct DeriVector2 {
    public var x: Parameter
    public var y: Parameter
    public var dx: Parameter
    public var dy: Parameter
    
    public init(x: Parameter = 0, y: Parameter = 0, dx: Parameter = 0, dy: Parameter = 0) {
        self.x = x
        self.y = y
        self.dx = dx
        self.dy = dy
    }
    
    public var point: SIMD2<Double> {
        SIMD2(x, y)
    }
    
    public var derivative: SIMD2<Double> {
        SIMD2(dx, dy)
    }
}

public class ParameterRef {
    public var value: Parameter
    
    public init(_ value: Parameter = 0) {
        self.value = value
    }
}

public struct Matrix {
    public var data: [Double]
    public let rows: Int
    public let cols: Int
    
    public init(rows: Int, cols: Int, data: [Double]? = nil) {
        self.rows = rows
        self.cols = cols
        self.data = data ?? Array(repeating: 0.0, count: rows * cols)
    }
    
    public subscript(row: Int, col: Int) -> Double {
        get {
            data[row * cols + col]
        }
        set {
            data[row * cols + col] = newValue
        }
    }
    
    public func transpose() -> Matrix {
        var result = Matrix(rows: cols, cols: rows)
        for i in 0..<rows {
            for j in 0..<cols {
                result[j, i] = self[i, j]
            }
        }
        return result
    }
    
    public static func *(lhs: Matrix, rhs: Matrix) -> Matrix {
        precondition(lhs.cols == rhs.rows, "Matrix dimensions must match for multiplication")
        
        var result = Matrix(rows: lhs.rows, cols: rhs.cols)
        
        cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                    Int32(lhs.rows), Int32(rhs.cols), Int32(lhs.cols),
                    1.0, lhs.data, Int32(lhs.cols),
                    rhs.data, Int32(rhs.cols),
                    0.0, &result.data, Int32(rhs.cols))
        
        return result
    }
    
    public static func +(lhs: Matrix, rhs: Matrix) -> Matrix {
        precondition(lhs.rows == rhs.rows && lhs.cols == rhs.cols, "Matrix dimensions must match")
        
        var result = Matrix(rows: lhs.rows, cols: lhs.cols)
        vDSP_vaddD(lhs.data, 1, rhs.data, 1, &result.data, 1, vDSP_Length(lhs.data.count))
        
        return result
    }
    
    public static func -(lhs: Matrix, rhs: Matrix) -> Matrix {
        precondition(lhs.rows == rhs.rows && lhs.cols == rhs.cols, "Matrix dimensions must match")
        
        var result = Matrix(rows: lhs.rows, cols: lhs.cols)
        vDSP_vsubD(rhs.data, 1, lhs.data, 1, &result.data, 1, vDSP_Length(lhs.data.count))
        
        return result
    }
    
    // Temporarily simplified QR decomposition without LAPACK
    public func qrDecomposition() -> (q: Matrix, r: Matrix) {
        // Return identity matrices for now - full implementation needs LAPACK fixes
        let q = Matrix.identity(size: rows)
        let r = self
        return (q: q, r: r)
    }
    
    /* Original LAPACK implementation - needs fixes for iOS
    public func qrDecomposition() -> (q: Matrix, r: Matrix) {
        var a = self.data
        var tau = Array(repeating: 0.0, count: min(rows, cols))
        var work = [Double](repeating: 0.0, count: 1)
        var lwork: __LAPACK_int = -1
        var info: __LAPACK_int = 0
        
        dgeqrf_(&(__LAPACK_int)(rows), &(__LAPACK_int)(cols), &a, &(__LAPACK_int)(rows),
                &tau, &work, &lwork, &info)
        
        lwork = __LAPACK_int(work[0])
        work = Array(repeating: 0.0, count: Int(lwork))
        
        dgeqrf_(&(__LAPACK_int)(rows), &(__LAPACK_int)(cols), &a, &(__LAPACK_int)(rows),
                &tau, &work, &lwork, &info)
        
        var r = Matrix(rows: min(rows, cols), cols: cols)
        for i in 0..<r.rows {
            for j in i..<r.cols {
                r[i, j] = a[i * cols + j]
            }
        }
        
        var q = Matrix(rows: rows, cols: min(rows, cols))
        for i in 0..<q.rows {
            for j in 0..<q.cols {
                q[i, j] = (i == j) ? 1.0 : 0.0
            }
        }
        
        dormqr_("L", "T", &(__LAPACK_int)(rows), &(__LAPACK_int)(q.cols), &(__LAPACK_int)(tau.count),
                &a, &(__LAPACK_int)(rows), &tau, &q.data, &(__LAPACK_int)(rows),
                &work, &lwork, &info)
        
        return (q, r)
    }
    */
    
    // Gaussian elimination with partial pivoting (works without LAPACK)
    public func solve(_ b: [Double]) -> [Double]? {
        guard rows == cols && rows == b.count else { return nil }
        guard rows > 0 else { return nil }
        
        // Create augmented matrix [A|b]
        var a = Array(repeating: Array(repeating: 0.0, count: cols), count: rows)
        for i in 0..<rows {
            for j in 0..<cols {
                a[i][j] = self[i, j]
            }
        }
        var x = b
        
        // Forward elimination with partial pivoting
        for k in 0..<rows {
            // Find pivot
            var maxRow = k
            var maxVal = abs(a[k][k])
            for i in (k+1)..<rows {
                if abs(a[i][k]) > maxVal {
                    maxVal = abs(a[i][k])
                    maxRow = i
                }
            }
            
            // Check for singular matrix
            if abs(a[maxRow][k]) < 1e-10 {
                return nil
            }
            
            // Swap rows
            if maxRow != k {
                a.swapAt(k, maxRow)
                let temp = x[k]
                x[k] = x[maxRow]
                x[maxRow] = temp
            }
            
            // Eliminate column
            for i in (k+1)..<rows {
                let factor = a[i][k] / a[k][k]
                for j in k..<cols {
                    a[i][j] -= factor * a[k][j]
                }
                x[i] -= factor * x[k]
            }
        }
        
        // Back substitution
        for i in (0..<rows).reversed() {
            for j in (i+1)..<cols {
                x[i] -= a[i][j] * x[j]
            }
            x[i] /= a[i][i]
        }
        
        return x
    }
    
    /* Original LAPACK implementation
    public func solve(_ b: [Double]) -> [Double]? {
        guard rows == cols && rows == b.count else { return nil }
        
        var a = self.data
        var x = b
        var ipiv = Array(repeating: __LAPACK_int(0), count: rows)
        var info: __LAPACK_int = 0
        
        dgesv_(&(__LAPACK_int)(rows), &(__LAPACK_int)(1), &a, &(__LAPACK_int)(rows),
               &ipiv, &x, &(__LAPACK_int)(rows), &info)
        
        return info == 0 ? x : nil
    }
    */
    
    public static func identity(size: Int) -> Matrix {
        var result = Matrix(rows: size, cols: size)
        for i in 0..<size {
            result[i, i] = 1.0
        }
        return result
    }
    
    public func norm() -> Double {
        var result = 0.0
        vDSP_svesqD(data, 1, &result, vDSP_Length(data.count))
        return sqrt(result)
    }
}

public extension Array where Element == Double {
    func dot(_ other: [Double]) -> Double {
        precondition(count == other.count, "Arrays must have same length")
        var result = 0.0
        vDSP_dotprD(self, 1, other, 1, &result, vDSP_Length(count))
        return result
    }
    
    func norm() -> Double {
        var result = 0.0
        vDSP_svesqD(self, 1, &result, vDSP_Length(count))
        return sqrt(result)
    }
    
    static func +(lhs: [Double], rhs: [Double]) -> [Double] {
        precondition(lhs.count == rhs.count, "Arrays must have same length")
        var result = Array(repeating: 0.0, count: lhs.count)
        vDSP_vaddD(lhs, 1, rhs, 1, &result, 1, vDSP_Length(lhs.count))
        return result
    }
    
    static func -(lhs: [Double], rhs: [Double]) -> [Double] {
        precondition(lhs.count == rhs.count, "Arrays must have same length")
        var result = Array(repeating: 0.0, count: lhs.count)
        vDSP_vsubD(rhs, 1, lhs, 1, &result, 1, vDSP_Length(lhs.count))
        return result
    }
    
    static func *(lhs: Double, rhs: [Double]) -> [Double] {
        var result = Array(repeating: 0.0, count: rhs.count)
        var scalar = lhs
        vDSP_vsmulD(rhs, 1, &scalar, &result, 1, vDSP_Length(rhs.count))
        return result
    }
}