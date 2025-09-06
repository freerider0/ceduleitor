import Foundation
import CoreLocation

// ==================================================
// MARK: - Location Service
// ==================================================
/// Manages GPS location tracking with proper error handling
/// Ensures the app never crashes due to location issues
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: - Published Properties
    @Published var currentLocation: CLLocation?
    @Published var hasLocationPermission = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var isUpdatingLocation = false
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
        checkLocationPermission()
    }
    
    // MARK: - Setup
    /// Configure location manager with safe defaults
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Set distance filter to avoid excessive updates
        locationManager.distanceFilter = 10.0 // Update every 10 meters
    }
    
    // MARK: - Permission Management
    /// Check and request location permissions
    func checkLocationPermission() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch self.locationManager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.hasLocationPermission = true
                self.errorMessage = nil
                // Only start updating if not already updating
                if !self.isUpdatingLocation {
                    self.startUpdatingLocation()
                }
                
            case .notDetermined:
                // Request permission
                self.locationManager.requestWhenInUseAuthorization()
                
            case .restricted:
                self.hasLocationPermission = false
                self.errorMessage = "Location access is restricted on this device"
                
            case .denied:
                self.hasLocationPermission = false
                self.errorMessage = "Location permission denied. Please enable in Settings."
                
            @unknown default:
                self.hasLocationPermission = false
                self.errorMessage = "Unknown location permission status"
            }
        }
    }
    
    // MARK: - Location Updates
    /// Start updating location with safety checks
    func startUpdatingLocation() {
        guard hasLocationPermission else {
            print("Cannot start location updates: permission not granted")
            return
        }
        
        guard !isUpdatingLocation else {
            print("Already updating location")
            return
        }
        
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }
    
    /// Stop location updates
    func stopUpdatingLocation() {
        guard isUpdatingLocation else { return }
        
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Location Accessors
    /// Get current location coordinates safely
    func getCurrentLocation() -> (latitude: Double, longitude: Double)? {
        guard let location = currentLocation else {
            print("Location not available")
            return nil
        }
        
        // Validate coordinates are reasonable
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        guard lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 else {
            print("Invalid coordinates: \(lat), \(lon)")
            return nil
        }
        
        return (latitude: lat, longitude: lon)
    }
    
    /// Get formatted location string for display
    func getLocationString() -> String {
        guard let location = currentLocation else {
            return "Location not available"
        }
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // Validate coordinates
        guard lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 else {
            return "Invalid location"
        }
        
        return String(format: "%.6f, %.6f", lat, lon)
    }
    
    // MARK: - CLLocationManagerDelegate
    
    /// Handle authorization changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationPermission()
    }
    
    /// Handle location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Filter out invalid or cached locations
        let age = -newLocation.timestamp.timeIntervalSinceNow
        
        // Ignore locations older than 5 seconds
        guard age < 5.0 else {
            print("Ignoring cached location")
            return
        }
        
        // Ignore locations with poor accuracy
        guard newLocation.horizontalAccuracy > 0 && newLocation.horizontalAccuracy < 100 else {
            print("Ignoring inaccurate location: \(newLocation.horizontalAccuracy)m")
            return
        }
        
        // Update current location
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = newLocation
            self?.errorMessage = nil
        }
    }
    
    /// Handle location errors
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Don't stop on error - location might become available later
        print("Location error: \(error.localizedDescription)")
        
        // Handle specific error codes
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "Location permission denied"
                    self?.hasLocationPermission = false
                }
                stopUpdatingLocation()
                
            case .locationUnknown:
                // Temporary error, keep trying
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "Location temporarily unavailable"
                }
                
            case .network:
                // Network error, location might still work
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "Location network error"
                }
                
            default:
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "Location error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        stopUpdatingLocation()
    }
}