//
//  Main.swift
//  SlashScan
//
//  Created by HC on 9/18/24.
//

import UIKit
import MapKit
import CoreLocation

// MARK: - CustomAnnotation Class
class CustomAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var isCSV: Bool
    var csvFileName: String?
    var altitude: Double?
    var project: String?
    var name: String?
    var volume: Double?

    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, isCSV: Bool, csvFileName: String?, altitude: Double?, project: String?, name: String?, volume: Double?) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.isCSV = isCSV
        self.csvFileName = csvFileName
        self.altitude = altitude
        self.project = project
        self.name = name
        self.volume = volume
    }
}

// MARK: - FileInfo
struct FileInfo {
    var fileName: String
    var hasCoordinates: Bool
    var latitude: Double?
    var longitude: Double?
    var project: String?
    var name: String?
    var altitude: Double?
    var volume: Double?
}

// MARK: - OfflineMapInfo
struct OfflineMapInfo {
    var mapName: String
    var fileURL: URL
    var regionCenter: CLLocationCoordinate2D
    var regionSpan: MKCoordinateSpan
    var mapType: MKMapType
    var fileCreatedAt: Date?
}

// MARK: - MapViewController
class MapViewController: UIViewController, CLLocationManagerDelegate, UIGestureRecognizerDelegate {

    var mapView: MKMapView!
    let locationManager = CLLocationManager()
    var compassButton: MKCompassButton!
    var scaleView: MKScaleView!

    var locateButton: UIButton!
    var mapTypeButton: UIButton!
    var addButton: UIButton!
    var editcoordsButton: UIButton!
    var searchBar: UISearchBar!

    var tableView: UITableView!
    var searchCompleter: MKLocalSearchCompleter!
    var searchResults = [MKLocalSearchCompletion]()

    var scannedFiles: [FileInfo] = []
    let geocoder = CLGeocoder()

    var longPressGesture: UILongPressGestureRecognizer!
    var doubleTapGesture: UITapGestureRecognizer!
    var pinCount = 0

    // 기존 오프라인 버튼 -> Offline Map 버튼으로 바꿔줍니다.
    var offlineButton: UIButton!

    // 2. "오프라인 목록" UI (테이블뷰)
    var offlineMapsTableView: UITableView!
    var offlineMaps: [OfflineMapInfo] = []      // 저장된 오프라인 맵 목록

    // 목록 하단 버튼들
    var createNewButton: UIButton!
    var cancelButton: UIButton!

    // 4. 카메라 아이콘(새 맵 생성 시 사용)
    var captureButton: UIButton!
    var isCreatingNewOfflineMap: Bool = false

    // 현재 지도에 오버레이된 오프라인 맵(토글 용)
    var currentOfflineOverlay: OfflineOverlay?

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView = MKMapView(frame: view.frame)
        mapView.showsCompass = false
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = self
        mapView.mapType = .hybrid
        view.addSubview(mapView)

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()

        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
            mapView.showsUserLocation = true
        }

        setupCompassButton()
        setupScaleView()
        setupMapTypeButton()
        setupLocateButton()
        setupAddButton()
        setupOfflineButton()
        setupOfflineMapsTableView()
        setupOfflineMapsBottomButtons()
        setupeditcoordsButton()
        setupSearchBar()
        setupSearchCompleter()
        setupTableView()
        setupDoubleTapGestureRecognizer()
        setupLongPressGestureRecognizer()

        loadOfflineMaps()
        loadAnnotationsFromCSV()
        loadPinpointsFromCSV()

        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
    }
    
    func setupeditcoordsButton() {
        editcoordsButton = UIButton(type: .system)
        editcoordsButton.translatesAutoresizingMaskIntoConstraints = false
        editcoordsButton.backgroundColor = .systemGray
        editcoordsButton.setImage(UIImage(systemName: "globe"), for: .normal)
        editcoordsButton.tintColor = .white
//        editcoordsButton.setTitleColor(.white, for: .normal)
//        editcoordsButton.setTitle("Edit\nXYZ", for: .normal)
//        editcoordsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
//        editcoordsButton.titleLabel?.numberOfLines = 2
//        editcoordsButton.titleLabel?.textAlignment = .center
        editcoordsButton.layer.cornerRadius = 30
        editcoordsButton.clipsToBounds = true
        
        editcoordsButton.layer.shadowColor = UIColor.black.cgColor
        editcoordsButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        editcoordsButton.layer.shadowOpacity = 0.3
        editcoordsButton.layer.shadowRadius = 2
        
        editcoordsButton.addTarget(self, action: #selector(editcoordsButtonTapped), for: .touchUpInside)
        view.addSubview(editcoordsButton)

        NSLayoutConstraint.activate([
            editcoordsButton.widthAnchor.constraint(equalToConstant: 60),
            editcoordsButton.heightAnchor.constraint(equalToConstant: 60),
            editcoordsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            editcoordsButton.bottomAnchor.constraint(equalTo: offlineButton.topAnchor, constant: -10)
        ])
    }

    func setupOfflineButton() {
        offlineButton = UIButton(type: .system)
        offlineButton.translatesAutoresizingMaskIntoConstraints = false
        offlineButton.backgroundColor = .systemGray
        offlineButton.setTitleColor(.white, for: .normal)
        offlineButton.setTitle("Offline\nMap", for: .normal)
        offlineButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        offlineButton.titleLabel?.numberOfLines = 2
        offlineButton.titleLabel?.textAlignment = .center
        offlineButton.layer.cornerRadius = 30
        offlineButton.clipsToBounds = true

        offlineButton.layer.shadowColor = UIColor.black.cgColor
        offlineButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        offlineButton.layer.shadowOpacity = 0.3
        offlineButton.layer.shadowRadius = 2

        offlineButton.addTarget(self, action: #selector(showOfflineMapsTableView), for: .touchUpInside)
        view.addSubview(offlineButton)

        NSLayoutConstraint.activate([
            offlineButton.widthAnchor.constraint(equalToConstant: 60),
            offlineButton.heightAnchor.constraint(equalToConstant: 60),
            offlineButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            offlineButton.bottomAnchor.constraint(equalTo: scaleView.topAnchor, constant: -10)
        ])
    }

    func setupOfflineMapsTableView() {
        offlineMapsTableView = UITableView()
        offlineMapsTableView.translatesAutoresizingMaskIntoConstraints = false
        offlineMapsTableView.isHidden = true
        offlineMapsTableView.delegate = self
        offlineMapsTableView.dataSource = self

        offlineMapsTableView.register(OfflineMapCell.self, forCellReuseIdentifier: "OfflineMapCell")
        
        offlineMapsTableView.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        offlineMapsTableView.layer.cornerRadius = 20
        view.addSubview(offlineMapsTableView)

        NSLayoutConstraint.activate([
            offlineMapsTableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            offlineMapsTableView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            offlineMapsTableView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            offlineMapsTableView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4)
        ])
    }

    func setupOfflineMapsBottomButtons() {
        
        cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.backgroundColor = .white
        cancelButton.setTitleColor(.systemRed, for: .normal)
        cancelButton.layer.cornerRadius = 5
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
        createNewButton = UIButton(type: .system)
        createNewButton.setTitle("Create New", for: .normal)
        createNewButton.backgroundColor = .systemGreen
        createNewButton.setTitleColor(.white, for: .normal)
        createNewButton.layer.cornerRadius = 5
        createNewButton.addTarget(self, action: #selector(createNewButtonTapped), for: .touchUpInside)

        // 하단 스택뷰로 정렬
        let bottomStackView = UIStackView(arrangedSubviews: [cancelButton,  createNewButton])
        bottomStackView.axis = .horizontal
        bottomStackView.distribution = .fillEqually
        bottomStackView.spacing = 20
        bottomStackView.translatesAutoresizingMaskIntoConstraints = false
        bottomStackView.isHidden = true  // 처음엔 숨김
        view.addSubview(bottomStackView)

        NSLayoutConstraint.activate([
            bottomStackView.topAnchor.constraint(equalTo: offlineMapsTableView.bottomAnchor, constant: 8),
            bottomStackView.centerXAnchor.constraint(equalTo: offlineMapsTableView.centerXAnchor),
            bottomStackView.widthAnchor.constraint(equalTo: offlineMapsTableView.widthAnchor),
            bottomStackView.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    func setupCaptureButton() {
        // Capture Button 설정
        captureButton = UIButton(type: .system)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        captureButton.backgroundColor = .systemBlue
        captureButton.tintColor = .white
        captureButton.layer.cornerRadius = 30
        captureButton.clipsToBounds = true
        captureButton.layer.shadowColor = UIColor.black.cgColor
        captureButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        captureButton.layer.shadowOpacity = 0.3
        captureButton.layer.shadowRadius = 2
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        view.addSubview(captureButton)

        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 60),
            captureButton.heightAnchor.constraint(equalToConstant: 60)
        ])
        let instructionsLabel = UILabel()
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionsLabel.text = "Adjust map, zoom level, and press the button to capture."
        instructionsLabel.font = UIFont.systemFont(ofSize: 14)
        instructionsLabel.textColor = .darkGray
        instructionsLabel.textAlignment = .center
        instructionsLabel.backgroundColor = .white
        instructionsLabel.numberOfLines = 0
        view.addSubview(instructionsLabel)

        NSLayoutConstraint.activate([
            instructionsLabel.topAnchor.constraint(equalTo: captureButton.bottomAnchor, constant: 10),
            instructionsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionsLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            instructionsLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        instructionsLabel.accessibilityHint = "instructionsLabel"
    }

    func setupCompassButton() {
        compassButton = MKCompassButton(mapView: mapView)
        compassButton.compassVisibility = .visible
        compassButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(compassButton)

        NSLayoutConstraint.activate([
            compassButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            compassButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
    }

    func setupScaleView() {
        scaleView = MKScaleView(mapView: mapView)
        scaleView.legendAlignment = .trailing
        scaleView.scaleVisibility = .visible
        scaleView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scaleView)

        NSLayoutConstraint.activate([
            scaleView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            scaleView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
    }

    func setupLocateButton() {
        locateButton = UIButton(type: .system)
        locateButton.translatesAutoresizingMaskIntoConstraints = false
        locateButton.backgroundColor = .systemBlue
        locateButton.setImage(UIImage(systemName: "location.fill"), for: .normal)
        locateButton.tintColor = .white
        locateButton.layer.cornerRadius = 30
        locateButton.clipsToBounds = true
        locateButton.layer.shadowColor = UIColor.black.cgColor
        locateButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        locateButton.layer.shadowOpacity = 0.3
        locateButton.layer.shadowRadius = 2
        locateButton.addTarget(self, action: #selector(locateButtonTapped), for: .touchUpInside)
        view.addSubview(locateButton)

        NSLayoutConstraint.activate([
            locateButton.widthAnchor.constraint(equalToConstant: 60),
            locateButton.heightAnchor.constraint(equalToConstant: 60),
            locateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            locateButton.bottomAnchor.constraint(equalTo: mapTypeButton.topAnchor, constant: -10)
        ])
    }
    
    func setupMapTypeButton() {
        mapTypeButton = UIButton(type: .system)
        mapTypeButton.translatesAutoresizingMaskIntoConstraints = false
        mapTypeButton.backgroundColor = .systemGray
        mapTypeButton.setImage(UIImage(systemName: "map"), for: .normal)
        mapTypeButton.tintColor = .white
        mapTypeButton.layer.cornerRadius = 30
        mapTypeButton.clipsToBounds = true
        mapTypeButton.layer.shadowColor = UIColor.black.cgColor
        mapTypeButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        mapTypeButton.layer.shadowOpacity = 0.3
        mapTypeButton.layer.shadowRadius = 2
        mapTypeButton.addTarget(self, action: #selector(mapTypeButtonTapped), for: .touchUpInside)
        view.addSubview(mapTypeButton)

        NSLayoutConstraint.activate([
            mapTypeButton.widthAnchor.constraint(equalToConstant: 60),
            mapTypeButton.heightAnchor.constraint(equalToConstant: 60),
            mapTypeButton.bottomAnchor.constraint(equalTo: scaleView.topAnchor, constant: -10),
            mapTypeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
    }
    
    func setupAddButton() {
        addButton = UIButton(type: .system)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.setBackgroundImage(UIImage(systemName: "map.circle.fill"), for: .normal)
        addButton.tintColor = .systemGreen
        addButton.clipsToBounds = true
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        view.addSubview(addButton)
        
        let circleView = UIView()
        circleView.translatesAutoresizingMaskIntoConstraints = false
        circleView.backgroundColor = .white
        circleView.layer.cornerRadius = 25
        circleView.layer.masksToBounds = true
    
        view.insertSubview(circleView, belowSubview: addButton)
        
        NSLayoutConstraint.activate([
            circleView.widthAnchor.constraint(equalToConstant: 50),
            circleView.heightAnchor.constraint(equalToConstant: 50),
            circleView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            circleView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            addButton.widthAnchor.constraint(equalToConstant: 70),
            addButton.heightAnchor.constraint(equalToConstant: 70),
            addButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
        circleView.accessibilityHint = "circleView"
    }

    func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search..."
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        searchBar.backgroundColor = .clear

        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.backgroundColor = .white
            textField.layer.masksToBounds = true
            textField.layer.borderWidth = 0
            textField.textColor = .black
        }

        view.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            searchBar.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    func setupSearchCompleter() {
        searchCompleter = MKLocalSearchCompleter()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = .address
    }

    func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.isHidden = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            tableView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }

    func setupDoubleTapGestureRecognizer() {
        doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.delegate = self
        mapView.addGestureRecognizer(doubleTapGesture)
    }

    func setupLongPressGestureRecognizer() {
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.delegate = self
        mapView.addGestureRecognizer(longPressGesture)
    }

    // MARK: - Location Manager
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            let center = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let region = MKCoordinateRegion(center: center, latitudinalMeters: 2000, longitudinalMeters: 2000)
            mapView.setRegion(region, animated: true)
            locationManager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
        showAlert(title: "Location Error", message: error.localizedDescription)
    }

    // MARK: - Button Actions
    
    @objc func showOfflineMapsTableView() {
        loadOfflineMaps()
        offlineMapsTableView.isHidden = false
        if let stackView = view.subviews.first(where: { $0 is UIStackView && $0.subviews.contains(createNewButton) }) {
            stackView.isHidden = false
        }
    }

    @objc func locateButtonTapped() {
        if let userLocation = mapView.userLocation.location {
            let center = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
            let region = MKCoordinateRegion(center: center, latitudinalMeters: 2000, longitudinalMeters: 2000)
            mapView.setRegion(region, animated: true)
        }
    }

    @objc func mapTypeButtonTapped() {
        switch mapView.mapType {
        case .hybrid:
            mapView.mapType = .standard
            mapTypeButton.setImage(UIImage(systemName: "map"), for: .normal)
        default:
            mapView.mapType = .hybrid
            mapTypeButton.setImage(UIImage(systemName: "map.fill"), for: .normal)
        }
    }

    @objc func addButtonTapped() {
        dismiss(animated: true)
    }

    @objc func editcoordsButtonTapped() {
        scannedFiles = scanCSVFiles()

        let alertController = UIAlertController(title: "Edit Longitude/Latitude", message: nil, preferredStyle: .actionSheet)

        for file in scannedFiles {
            let title = file.hasCoordinates ? file.fileName : "\(file.fileName) (No Coordinates)"
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.presentCoordinateEditAlert(for: file)
            }
            alertController.addAction(action)
        }

        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = editcoordsButton
            popoverController.sourceRect = editcoordsButton.bounds
        }

        present(alertController, animated: true, completion: nil)
    }

    // MARK: - 새 Offline Map 생성 로직
    @objc func createNewButtonTapped() {
        offlineMapsTableView.isHidden = true
        if let stackView = view.subviews.first(where: { $0 is UIStackView && $0.subviews.contains(createNewButton) }) {
            stackView.isHidden = true
        }
        isCreatingNewOfflineMap = true
        setupCaptureButton()
        hideMainUI(true)
    }

    @objc func cancelButtonTapped() {
        offlineMapsTableView.isHidden = true
        if let stackView = view.subviews.first(where: { $0 is UIStackView && $0.subviews.contains(createNewButton) }) {
            stackView.isHidden = true
        }
    }

    @objc func captureButtonTapped() {
        let currentRegion = mapView.region
        let snapshotOptions = MKMapSnapshotter.Options()
        snapshotOptions.region = currentRegion
        snapshotOptions.size = mapView.frame.size
        snapshotOptions.scale = UIScreen.main.scale
        if mapView.mapType == .hybrid {
            snapshotOptions.mapType = .satellite
        } else {
            snapshotOptions.mapType = mapView.mapType
        }

        let snapshotter = MKMapSnapshotter(options: snapshotOptions)
        snapshotter.start { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                self.showAlert(title: "Failed", message: error.localizedDescription)
                return
            }
            guard let snapshot = snapshot else {
                self.showAlert(title: "Failed", message: "No snapshot.")
                return
            }

            let currentMapType = (self.mapView.mapType == .hybrid) ? .satellite : self.mapView.mapType

            let alert = UIAlertController(title: "Save Offline Map", message: "Enter map name:", preferredStyle: .alert)
            alert.addTextField { tf in
                tf.placeholder = "Offline map name"
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { _ in
                // UI 원복
                self.exitCreateNewMode()
            }))
            alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
                guard let name = alert.textFields?.first?.text, !name.isEmpty else {
                    self.showAlert(title: "Error", message: "Please enter a valid name.")
                    self.exitCreateNewMode()
                    return
                }

                guard let imageData = snapshot.image.pngData() else {
                    self.showAlert(title: "Error", message: "Failed to convert PNG.")
                    self.exitCreateNewMode()
                    return
                }

                let folderURL = self.getOfflineMapsDirectory()
                if !FileManager.default.fileExists(atPath: folderURL.path) {
                    try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                }

                let fileURL = folderURL.appendingPathComponent("\(name).png")
                do {
                    try imageData.write(to: fileURL)
                } catch {
                    self.showAlert(title: "Save Failed", message: error.localizedDescription)
                    self.exitCreateNewMode()
                    return
                }

                let metaURL = folderURL.appendingPathComponent("\(name).json")
                let metaDict: [String: Any] = [
                    "centerLat": currentRegion.center.latitude,
                    "centerLon": currentRegion.center.longitude,
                    "latSpan": currentRegion.span.latitudeDelta,
                    "lonSpan": currentRegion.span.longitudeDelta,
                    "mapType": currentMapType.rawValue
                ]
                if let jsonData = try? JSONSerialization.data(withJSONObject: metaDict, options: .prettyPrinted) {
                    try? jsonData.write(to: metaURL)
                }

                self.showAlert(title: "Success", message: "Offline map '\(name)' saved.")
                self.setupOfflineMapsTableView()
                self.exitCreateNewMode()
                self.showOfflineMapsTableView()

            }))
            self.present(alert, animated: true)
        }
    }

    func exitCreateNewMode() {
        isCreatingNewOfflineMap = false
        hideMainUI(false)
        captureButton?.removeFromSuperview()
        if let label = view.subviews.first(where: { $0 is UILabel && $0.accessibilityHint == "instructionsLabel" }) {
            label.removeFromSuperview()
        }
    }

    func hideMainUI(_ hide: Bool) {
        addButton.isHidden = hide
        editcoordsButton.isHidden = hide
        searchBar.isHidden = hide
        offlineButton.isHidden = hide
        if let circleview = view.subviews.first(where: { $0.accessibilityHint == "circleView" }) {
            circleview.isHidden = hide
        }
        if let label = view.subviews.first(where: { $0 is UILabel && $0.accessibilityHint == "instructionsLabel" }) {
            label.isHidden = !hide
        }
    }

    func showOfflineMapActionSheet(for offlineMap: OfflineMapInfo) {
        let alert = UIAlertController(title: offlineMap.mapName, message: nil, preferredStyle: .actionSheet)

        let overlayAction = UIAlertAction(title: "Overlay On/Off", style: .default) { _ in
            self.toggleOfflineOverlay(offlineMap: offlineMap)
        }
        let renameAction = UIAlertAction(title: "Rename", style: .default) { _ in
            self.renameOfflineMap(offlineMap: offlineMap)
        }
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteOfflineMap(offlineMap: offlineMap)
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)

        alert.addAction(overlayAction)
        alert.addAction(renameAction)
        alert.addAction(deleteAction)
        alert.addAction(cancel)

        if let popoverController = alert.popoverPresentationController,
           let index = offlineMaps.firstIndex(where: { $0.mapName == offlineMap.mapName }) {
            popoverController.sourceView = offlineMapsTableView
            let rect = offlineMapsTableView.rectForRow(at: IndexPath(row: index, section: 0))
            popoverController.sourceRect = rect
        }

        present(alert, animated: true, completion: nil)
    }

    func toggleOfflineOverlay(offlineMap: OfflineMapInfo) {
        if let currentOverlay = currentOfflineOverlay {
            mapView.removeOverlay(currentOverlay)
            if currentOverlay.offlineMapName == offlineMap.mapName {
                currentOfflineOverlay = nil
                offlineMapsTableView.reloadData()
                return
            } else {
                currentOfflineOverlay = nil
            }
        }
        guard let image = UIImage(contentsOfFile: offlineMap.fileURL.path) else {
            showAlert(title: "Error", message: "Cannot load offline image.")
            return
        }

        let center = offlineMap.regionCenter
        let latDelta = offlineMap.regionSpan.latitudeDelta
        let lonDelta = offlineMap.regionSpan.longitudeDelta
        let topLeft = CLLocationCoordinate2D(latitude: center.latitude + latDelta/2,
                                             longitude: center.longitude - lonDelta/2)
        let bottomRight = CLLocationCoordinate2D(latitude: center.latitude - latDelta/2,
                                                 longitude: center.longitude + lonDelta/2)
        let mapPointTopLeft = MKMapPoint(topLeft)
        let mapPointBottomRight = MKMapPoint(bottomRight)
        let mapRect = MKMapRect(
            x: mapPointTopLeft.x,
            y: mapPointTopLeft.y,
            width: mapPointBottomRight.x - mapPointTopLeft.x,
            height: mapPointBottomRight.y - mapPointTopLeft.y
        )

        let overlay = OfflineOverlay(boundingMapRect: mapRect, coordinate: center)
        overlay.offlineMapName = offlineMap.mapName
        currentOfflineOverlay = overlay
        mapView.addOverlay(overlay)
        offlineMapsTableView.reloadData()
    }

    /// Offline Map 이름 변경(파일이름, json이름 변경)
    func renameOfflineMap(offlineMap: OfflineMapInfo) {
        let alert = UIAlertController(title: "Rename", message: "Enter a new name:", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = offlineMap.mapName
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
            guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
            // 파일 rename
            let folder = self.getOfflineMapsDirectory()
            let oldPngURL = offlineMap.fileURL
            let oldJsonURL = folder.appendingPathComponent("\(offlineMap.mapName).json")

            let newPngURL = folder.appendingPathComponent("\(newName).png")
            let newJsonURL = folder.appendingPathComponent("\(newName).json")

            do {
                if FileManager.default.fileExists(atPath: oldPngURL.path) {
                    try FileManager.default.moveItem(at: oldPngURL, to: newPngURL)
                }
                if FileManager.default.fileExists(atPath: oldJsonURL.path) {
                    try FileManager.default.moveItem(at: oldJsonURL, to: newJsonURL)
                }
            } catch {
                self.showAlert(title: "Rename Failed", message: error.localizedDescription)
                return
            }

            self.showAlert(title: "Renamed", message: "'\(offlineMap.mapName)' → '\(newName)'")
            // 목록 갱신
            self.loadOfflineMaps()
            self.offlineMapsTableView.reloadData()
        }))
        present(alert, animated: true)
    }

    /// Offline Map 삭제
    func deleteOfflineMap(offlineMap: OfflineMapInfo) {
        let alert = UIAlertController(title: "Delete", message: "Delete '\(offlineMap.mapName)'?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            // 파일 삭제
            let folder = self.getOfflineMapsDirectory()
            let pngURL = offlineMap.fileURL
            let jsonURL = folder.appendingPathComponent("\(offlineMap.mapName).json")

            if FileManager.default.fileExists(atPath: pngURL.path) {
                try? FileManager.default.removeItem(at: pngURL)
            }
            if FileManager.default.fileExists(atPath: jsonURL.path) {
                try? FileManager.default.removeItem(at: jsonURL)
            }

            // 혹시 현재 오버레이 중이었다면 제거
            if let currentOverlay = self.currentOfflineOverlay,
               currentOverlay.offlineMapName == offlineMap.mapName {
                self.mapView.removeOverlay(currentOverlay)
                self.currentOfflineOverlay = nil
            }

            self.loadOfflineMaps()
            self.offlineMapsTableView.reloadData()
        }))
        present(alert, animated: true)
    }

    // MARK: - Offline Map 로딩
    func loadOfflineMaps() {
        offlineMaps.removeAll()
        let folderURL = getOfflineMapsDirectory()

        guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
        
        // (1) 폴더 내 .png 파일만 필터
        let pngFiles = fileURLs.filter { $0.pathExtension.lowercased() == "png" }
        
        for pngURL in pngFiles {
            let baseName = pngURL.deletingPathExtension().lastPathComponent
            let jsonURL = folderURL.appendingPathComponent("\(baseName).json")
            // json이 없으면 스킵
            guard FileManager.default.fileExists(atPath: jsonURL.path) else { continue }

            // JSON 파싱 (centerLat, centerLon, mapType 등)
            if let data = try? Data(contentsOf: jsonURL),
               let meta = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                
                // ...
                let centerLat   = meta["centerLat"] as? Double ?? 0
                let centerLon   = meta["centerLon"] as? Double ?? 0
                let latSpan     = meta["latSpan"]   as? Double ?? 0
                let lonSpan     = meta["lonSpan"]   as? Double ?? 0
                let mapTypeRaw  = meta["mapType"]   as? UInt   ?? MKMapType.standard.rawValue
                
                // (2) 파일 생성일자 읽어오기
                var creationDate: Date? = nil
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: pngURL.path)
                    creationDate = attrs[.creationDate] as? Date
                } catch {
                    print("Failed to get creationDate: \(error)")
                }
                
                let info = OfflineMapInfo(
                    mapName: baseName,
                    fileURL: pngURL,
                    regionCenter: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    regionSpan: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan),
                    mapType: MKMapType(rawValue: mapTypeRaw) ?? .standard,
                    fileCreatedAt: creationDate
                )
                offlineMaps.append(info)
            }
        }
        
        // 필요하면 정렬
        offlineMaps.sort { $0.mapName < $1.mapName }
    }

    // Documents/OfflineMaps
    func getOfflineMapsDirectory() -> URL {
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docURL.appendingPathComponent("OfflineMaps")
    }

    func getDocumentDirectory() -> URL {
        if let projectPath = UserDefaults.standard.string(forKey: "SelectedProjectFolder"),
           !projectPath.isEmpty {
            let projectURL = URL(fileURLWithPath: projectPath)
            if FileManager.default.fileExists(atPath: projectURL.path) {
                return projectURL
            }
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - 오래된 (자동) Offline 오버레이 로직은 필요 없으므로 주석 처리 or 수정
    /// 예전에는 앱 실행 시 바로 offlineMap.png를 불러왔으나,
    /// (6) "처음에는 오버레이 안되게" 하므로 기본 자동 호출 X
    func addOfflineMapOverlayIfAvailable() {
        // 필요하다면, 특정 OfflineMapInfo를 찾아서 addOverlay() 하는 식으로 수정 가능
    }

    // MARK: - CSV 관련
    func scanCSVFiles() -> [FileInfo] {
        var results: [FileInfo] = []
        let documentsURL = getDocumentDirectory()
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            let csvFiles = fileURLs.filter { $0.pathExtension.lowercased() == "csv" }

            var noCoords: [FileInfo] = []
            var withCoords: [FileInfo] = []

            for fileURL in csvFiles {
                let baseFilename = fileURL.deletingPathExtension().lastPathComponent
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                
                // pinpoints.csv 제외
                if baseFilename.lowercased() == "pinpoints" {
                    continue
                }

                guard lines.count > 1 else {
                    noCoords.append(FileInfo(fileName: baseFilename, hasCoordinates: false, latitude: nil, longitude: nil, project: nil, name: nil, altitude: nil, volume: nil))
                    continue
                }

                let headerLine = lines[0]
                let headers = headerLine.components(separatedBy: ",").map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

                let latitudeIndex = headers.firstIndex(of: "latitude")
                let longitudeIndex = headers.firstIndex(of: "longitude")
                let projectIndex = headers.firstIndex(of: "project")
                let nameIndex = headers.firstIndex(of: "name")
                let altitudeIndex = headers.firstIndex(of: "altitude")
                let volumeIndex = headers.firstIndex(of: "volume")

                let firstDataLine = lines[1]
                let fields = firstDataLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

                var lat: Double? = nil
                var lon: Double? = nil
                var proj: String? = nil
                var fname: String? = nil
                var alt: Double? = nil
                var vol: Double? = nil

                if let laIdx = latitudeIndex, laIdx < fields.count, let latVal = Double(fields[laIdx]) {
                    lat = latVal
                }
                if let loIdx = longitudeIndex, loIdx < fields.count, let lonVal = Double(fields[loIdx]) {
                    lon = lonVal
                }
                if let pIdx = projectIndex, pIdx < fields.count {
                    proj = fields[pIdx]
                }
                if let nIdx = nameIndex, nIdx < fields.count {
                    fname = fields[nIdx]
                }
                if let aIdx = altitudeIndex, aIdx < fields.count, let aVal = Double(fields[aIdx]) {
                    alt = aVal
                }
                if let vIdx = volumeIndex, vIdx < fields.count, let vVal = Double(fields[vIdx]) {
                    vol = vVal
                }

                if lat == nil || lon == nil {
                    noCoords.append(FileInfo(fileName: baseFilename, hasCoordinates: false, latitude: nil, longitude: nil, project: proj, name: fname, altitude: alt, volume: vol))
                } else {
                    withCoords.append(FileInfo(fileName: baseFilename, hasCoordinates: true, latitude: lat, longitude: lon, project: proj, name: fname, altitude: alt, volume: vol))
                }
            }
            results = noCoords + withCoords
            return results

        } catch {
            print("Error scanning CSV files: \(error)")
            showAlert(title: "Scan Error", message: "Failed to scan CSV files: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - 길게 눌러 핀포인트 생성
    @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        // 필요시 구현
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let touchPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            createPinpoint(at: coordinate)
        }
    }

    func createPinpoint(at coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        pinCount += 1
        let pinTitle = "Pin \(pinCount)"

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            if let error = error {
                print("Reverse geocoding failed: \(error.localizedDescription)")
                self.showAlert(title: "Failed to get address", message: error.localizedDescription)
                return
            }

            var addressString = ""
            if let placemark = placemarks?.first {
                if let name = placemark.name { addressString += name }
                if let thoroughfare = placemark.thoroughfare { addressString += " \(thoroughfare)" }
                if let locality = placemark.locality { addressString += " \(locality)" }
                if let administrativeArea = placemark.administrativeArea { addressString += " \(administrativeArea)" }
                if let country = placemark.country { addressString += " \(country)" }
            }
            let message = [
                "Address: \(addressString)",
                String(format: "Latitude: %.6f", coordinate.latitude),
                String(format: "Longitude: %.6f", coordinate.longitude)
            ].joined(separator: "\n")

            let annotation = CustomAnnotation(
                coordinate: coordinate,
                title: pinTitle,
                subtitle: message,
                isCSV: false,
                csvFileName: nil,
                altitude: nil,
                project: nil,
                name: pinTitle,
                volume: nil
            )
            self.mapView.addAnnotation(annotation)
            self.savePinpointsToCSV()
        }
    }

    // MARK: - CSV 업데이트 (Latitude, Longitude, Altitude 모두 처리)
    func updateCSVFile(fileInfo: FileInfo, newLat: Double, newLon: Double, newAlt: Double) {
        let docURL = getDocumentDirectory().appendingPathComponent(fileInfo.fileName + ".csv")
        guard FileManager.default.fileExists(atPath: docURL.path) else {
            showAlert(title: "Error", message: "Cannot find the file.")
            return
        }
        
        // pinpoints.csv는 제외
        if fileInfo.fileName.lowercased() == "pinpoints" {
            return
        }

        do {
            let content = try String(contentsOf: docURL, encoding: .utf8)
            var lines = content.components(separatedBy: .newlines)
            guard lines.count > 1 else { return }

            // 헤더
            let headerLine = lines[0]
            let headers = headerLine
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

            // latitude, longitude, altitude 인덱스 찾기
            guard let latIndex = headers.firstIndex(where: { $0 == "latitude" }),
                  let lonIndex = headers.firstIndex(where: { $0 == "longitude" }) else {
                showAlert(title: "Error", message: "No latitude/longitude columns.")
                return
            }
            // altitude 컬럼은 없을 수도 있으니 옵셔널로 처리
            let altIndex = headers.firstIndex(where: { $0 == "altitude" })

            // 실제 데이터는 1번 라인
            var dataLine = lines[1].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if latIndex < dataLine.count { dataLine[latIndex] = "\(newLat)" }
            if lonIndex < dataLine.count { dataLine[lonIndex] = "\(newLon)" }
            if let altIdx = altIndex, altIdx < dataLine.count {
                dataLine[altIdx] = "\(newAlt)"
            }
            lines[1] = dataLine.joined(separator: ",")
            let newContent = lines.joined(separator: "\n")
            try newContent.write(to: docURL, atomically: true, encoding: .utf8)

            showAlert(title: "Save Complete", message: "Coordinates updated.")
        } catch {
            showAlert(title: "Error", message: "Failed to update: \(error.localizedDescription)")
        }
    }

    func presentCoordinateEditAlert(for fileInfo: FileInfo) {
        let alert = UIAlertController(
            title: "Edit Coordinates for '\(fileInfo.fileName)'",
            message: "Please enter new latitude, longitude, and altitude.",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Latitude"
            if let lat = fileInfo.latitude {
                textField.text = "\(lat)"
            }
            textField.keyboardType = .decimalPad
        }
        alert.addTextField { textField in
            textField.placeholder = "Longitude"
            if let lon = fileInfo.longitude {
                textField.text = "\(lon)"
            }
            textField.keyboardType = .decimalPad
        }
        alert.addTextField { textField in
            textField.placeholder = "Altitude"
            if let alt = fileInfo.altitude {
                textField.text = "\(alt)"
            }
            textField.keyboardType = .decimalPad
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
            guard let latText = alert.textFields?[0].text, let latVal = Double(latText),
                  let lonText = alert.textFields?[1].text, let lonVal = Double(lonText),
                  let altText = alert.textFields?[2].text, let altVal = Double(altText)
            else {
                self.showAlert(title: "Error", message: "Invalid number.")
                return
            }
            self.updateCSVFile(fileInfo: fileInfo, newLat: latVal, newLon: lonVal, newAlt: altVal)
        }))
        
        present(alert, animated: true)
    }

    func pinpointsCSVURL() -> URL {
        return getDocumentDirectory().appendingPathComponent("pinpoints.csv")
    }

    func loadPinpointsFromCSV() {
        let fileURL = pinpointsCSVURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            guard lines.count > 1 else { return }

            let header = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let nameIndex = header.firstIndex(of: "name"),
                  let latIndex = header.firstIndex(of: "latitude"),
                  let lonIndex = header.firstIndex(of: "longitude"),
                  let addressIndex = header.firstIndex(of: "address") else {
                return
            }
            for line in lines.dropFirst() {
                let fields = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if fields.count < header.count { continue }

                let name = fields[nameIndex]
                guard let latitude = Double(fields[latIndex]),
                      let longitude = Double(fields[lonIndex]) else { continue }
                let address = fields[addressIndex]

                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                let annotation = CustomAnnotation(
                    coordinate: coordinate,
                    title: name,
                    subtitle: "Address: \(address)\nLatitude: \(latitude)\nLongitude: \(longitude)",
                    isCSV: false,
                    csvFileName: nil,
                    altitude: nil,
                    project: nil,
                    name: name,
                    volume: nil
                )
                mapView.addAnnotation(annotation)
            }

        } catch {
            print("Failed to load pinpoints.csv: \(error.localizedDescription)")
            showAlert(title: "Load Error", message: "Failed to load pinpoints.")
        }
    }

    func savePinpointsToCSV() {
        let userPinpoints = mapView.annotations.compactMap { $0 as? CustomAnnotation }.filter { !$0.isCSV }

        var csvString = "name,latitude,longitude,address\n"
        for pinpoint in userPinpoints {
            let lat = pinpoint.coordinate.latitude
            let lon = pinpoint.coordinate.longitude
            var address = ""
            if let subtitle = pinpoint.subtitle {
                let lines = subtitle.components(separatedBy: "\n")
                if let addrLine = lines.first(where: { $0.starts(with: "Address: ") }) {
                    address = String(addrLine.dropFirst("Address: ".count))
                }
            }
            let safeName = (pinpoint.title?.contains(",") == true) ? "\"\(pinpoint.title ?? "")\"" : (pinpoint.title ?? "")
            let safeAddress = address.contains(",") ? "\"\(address)\"" : address
            csvString += "\(safeName),\(lat),\(lon),\(safeAddress)\n"
        }

        let fileURL = pinpointsCSVURL()
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("pinpoints.csv saved.")
        } catch {
            print("Failed to save pinpoints.csv: \(error.localizedDescription)")
            showAlert(title: "Save Error", message: "Failed to save pinpoints.")
        }
    }

    func createCustomCalloutView(for annotation: CustomAnnotation) -> UIView {
        let calloutView = UIView()
        calloutView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = annotation.subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.numberOfLines = 0
        stackView.addArrangedSubview(subtitleLabel)

        let buttonsStackView = UIStackView()
        buttonsStackView.axis = .horizontal
        buttonsStackView.spacing = 10
        buttonsStackView.distribution = .fillEqually

        let renameButton = UIButton(type: .system)
        renameButton.setTitle("Rename", for: .normal)
        renameButton.tag = 1
        renameButton.addTarget(self, action: #selector(calloutButtonTapped(_:)), for: .touchUpInside)
        buttonsStackView.addArrangedSubview(renameButton)

        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle("Delete", for: .normal)
        deleteButton.tag = 2
        deleteButton.addTarget(self, action: #selector(calloutButtonTapped(_:)), for: .touchUpInside)
        buttonsStackView.addArrangedSubview(deleteButton)

        if annotation.isCSV {
            let view3DButton = UIButton(type: .system)
            view3DButton.setTitle("3D View", for: .normal)
            view3DButton.tag = 3
            view3DButton.addTarget(self, action: #selector(calloutButtonTapped(_:)), for: .touchUpInside)
            buttonsStackView.addArrangedSubview(view3DButton)
        }

        stackView.addArrangedSubview(buttonsStackView)
        calloutView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: calloutView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: calloutView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: calloutView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: calloutView.bottomAnchor)
        ])

        return calloutView
    }

    @objc func calloutButtonTapped(_ sender: UIButton) {
        guard let annotation = mapView.selectedAnnotations.first as? CustomAnnotation else {
            return
        }

        switch sender.tag {
        case 1:
            presentRenameAlert(for: annotation)
        case 2:
            confirmDeletion(of: annotation)
        case 3:
            open3DView(for: annotation)
        default:
            break
        }
    }

    func presentRenameAlert(for annotation: CustomAnnotation) {
        let alert = UIAlertController(title: "Rename Annotation", message: "Enter a new name", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "New name"
            textField.text = annotation.title
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { _ in
            if let newName = alert.textFields?.first?.text, !newName.isEmpty {
                annotation.title = newName
                self.mapView.removeAnnotation(annotation)
                self.mapView.addAnnotation(annotation)
                self.savePinpointsToCSV()
            }
        }))
        present(alert, animated: true)
    }

    func confirmDeletion(of annotation: CustomAnnotation) {
        let alert = UIAlertController(title: "Delete Annotation", message: "Are you sure?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            self.mapView.removeAnnotation(annotation)
            self.savePinpointsToCSV()
        }))
        present(alert, animated: true)
    }

    func open3DView(for annotation: CustomAnnotation) {
        guard annotation.isCSV, let csvName = annotation.csvFileName else {
            showAlert(title: "Error", message: "No associated project.")
            return
        }

        let docURL = getDocumentDirectory()
        let dbURL = docURL.appendingPathComponent(csvName + ".db")

        if !FileManager.default.fileExists(atPath: dbURL.path) {
            showAlert(title: "Error", message: "Database file not found.")
            return
        }

        dismiss(animated: true) {
            // 3D 뷰 열기
            print("Open 3D with DB: \(dbURL.path)")
        }
    }

    func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    // CSV 파일에서 Annotation 로드
    func loadAnnotationsFromCSV() {
        let documentsURL = getDocumentDirectory()
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            let csvFiles = fileURLs.filter { $0.pathExtension.lowercased() == "csv" }

            for fileURL in csvFiles {
                let baseFilename = fileURL.deletingPathExtension().lastPathComponent
                let dbFileURL = documentsURL.appendingPathComponent("\(baseFilename).db")
                if !FileManager.default.fileExists(atPath: dbFileURL.path) { continue }

                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                guard !lines.isEmpty else { continue }

                let headerLine = lines[0]
                let headers = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

                let projectIndex = headers.firstIndex(of: "project") ?? -1
                let nameIndex = headers.firstIndex(of: "name") ?? -1
                let latitudeIndex = headers.firstIndex(of: "latitude") ?? -1
                let longitudeIndex = headers.firstIndex(of: "longitude") ?? -1
                let altitudeIndex = headers.firstIndex(of: "altitude") ?? -1
                let volumeIndex = headers.firstIndex(of: "volume") ?? -1

                if latitudeIndex == -1 || longitudeIndex == -1 || altitudeIndex == -1 || volumeIndex == -1 {
                    continue
                }

                for line in lines[1...] {
                    let fields = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    guard fields.count >= headers.count else { continue }

                    guard let latitude = Double(fields[latitudeIndex]),
                          let longitude = Double(fields[longitudeIndex]),
                          let altitude = Double(fields[altitudeIndex]),
                          let volume = Double(fields[volumeIndex]) else { continue }

                    let project = projectIndex != -1 ? fields[projectIndex] : ""
                    let name = nameIndex != -1 ? fields[nameIndex] : baseFilename
                    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

                    let messageLines: [String]
                    if UserDefaults.standard.integer(forKey: "MeasurementUnit") == 0 {
                        messageLines = [
                            "Project: \(project)",
                            "Name: \(name)",
                            String(format: "Latitude: %.6f", latitude),
                            String(format: "Longitude: %.6f", longitude),
                            String(format: "Altitude: %.2f m", altitude),
                            String(format: "Volume: %.3f m³", volume)
                        ]
                    } else {
                        let altitudeInFeet = round(100 * altitude * 3.28084) / 100
                        let volumeInCubicFeet = round(100 * volume * 35.3147) / 100
                        messageLines = [
                            "Project: \(project)",
                            "Name: \(name)",
                            String(format: "Latitude: %.6f", latitude),
                            String(format: "Longitude: %.6f", longitude),
                            String(format: "Altitude: %.2f ft", altitudeInFeet),
                            String(format: "Volume: %.3f ft³", volumeInCubicFeet)
                        ]
                    }

                    let annotation = CustomAnnotation(
                        coordinate: coordinate,
                        title: name.isEmpty ? baseFilename : name,
                        subtitle: messageLines.joined(separator: "\n"),
                        isCSV: true,
                        csvFileName: baseFilename,
                        altitude: altitude,
                        project: project,
                        name: name,
                        volume: volume
                    )
                    mapView.addAnnotation(annotation)

                    let location = CLLocation(latitude: latitude, longitude: longitude)
                    geocoder.reverseGeocodeLocation(location) { [weak self, weak annotation] placemarks, error in
                        guard let self = self, let annotation = annotation else { return }
                        if let placemark = placemarks?.first {
                            var addressString = ""
                            if let name = placemark.name { addressString += name }
                            if let thoroughfare = placemark.thoroughfare { addressString += " \(thoroughfare)" }
                            if let locality = placemark.locality { addressString += " \(locality)" }
                            if let administrativeArea = placemark.administrativeArea { addressString += " \(administrativeArea)" }
                            if let country = placemark.country { addressString += " \(country)" }
                            
                            let updatedMessage: String
                            if UserDefaults.standard.integer(forKey: "MeasurementUnit") == 0 {
                                updatedMessage = [
                                    "Address: \(addressString)",
                                    "Project: \(annotation.project ?? "")",
                                    "Name: \(annotation.name ?? "")",
                                    String(format: "Latitude: %.6f", annotation.coordinate.latitude),
                                    String(format: "Longitude: %.6f", annotation.coordinate.longitude),
                                    String(format: "Altitude: %.2f m", annotation.altitude ?? 0.0),
                                    String(format: "Volume: %.3f m³", annotation.volume ?? 0.0),
                                ].joined(separator: "\n")
                            } else {
                                let altitudeInFeet = round(100 * (annotation.altitude ?? 0.0) * 3.28084) / 100
                                let volumeInCubicFeet = round(100 * (annotation.volume ?? 0.0) * 35.3147) / 100
                                updatedMessage = [
                                    "Address: \(addressString)",
                                    "Project: \(annotation.project ?? "")",
                                    "Name: \(annotation.name ?? "")",
                                    String(format: "Latitude: %.6f", annotation.coordinate.latitude),
                                    String(format: "Longitude: %.6f", annotation.coordinate.longitude),
                                    String(format: "Altitude: %.2f ft", altitudeInFeet),
                                    String(format: "Volume: %.3f ft³", volumeInCubicFeet),
                                ].joined(separator: "\n")
                            }

                            DispatchQueue.main.async {
                                annotation.subtitle = updatedMessage
                                if let view = self.mapView.view(for: annotation) {
                                    view.detailCalloutAccessoryView = self.createCustomCalloutView(for: annotation)
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            print("Error loading CSV files: \(error.localizedDescription)")
            showAlert(title: "CSV Load Error", message: error.localizedDescription)
        }
    }
}

// MARK: - MKMapViewDelegate
extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }

        if let cluster = annotation as? MKClusterAnnotation {
            var clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: "Cluster") as? MKMarkerAnnotationView
            if clusterView == nil {
                clusterView = MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: "Cluster")
                clusterView?.canShowCallout = true
            } else {
                clusterView?.annotation = cluster
            }

            let firstMember = cluster.memberAnnotations.first
            var clusterType: String = "mixed"
            if let firstAnnotation = firstMember as? CustomAnnotation {
                let isCSV = firstAnnotation.isCSV
                let allSameType = cluster.memberAnnotations.allSatisfy { ($0 as? CustomAnnotation)?.isCSV == isCSV }
                if allSameType {
                    clusterType = isCSV ? "csvCluster" : "pinpointCluster"
                }
            }

            if clusterType == "csvCluster" {
                clusterView?.markerTintColor = .systemBlue
                clusterView?.glyphImage = UIImage(systemName: "flag.fill")
            } else if clusterType == "pinpointCluster" {
                clusterView?.markerTintColor = .systemRed
                clusterView?.glyphImage = UIImage(systemName: "mappin")
            } else {
                clusterView?.markerTintColor = .gray
                clusterView?.glyphImage = UIImage(systemName: "questionmark")
            }

            clusterView?.glyphText = "\(cluster.memberAnnotations.count)"
            clusterView?.titleVisibility = .visible
            clusterView?.subtitleVisibility = .visible

            let titles = cluster.memberAnnotations.compactMap { ($0 as? CustomAnnotation)?.title }
            let uniqueTitles = Set(titles)
            let name = uniqueTitles.first ?? ""
            cluster.title = "\(name)"
            return clusterView
        }

        guard let customAnnotation = annotation as? CustomAnnotation else {
            return nil
        }

        let identifier = customAnnotation.isCSV ? "CSVAnnotation" : "UserAnnotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: customAnnotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = customAnnotation
        }

        if customAnnotation.isCSV {
            annotationView?.markerTintColor = .systemBlue
            annotationView?.glyphImage = UIImage(systemName: "flag.fill")
            annotationView?.clusteringIdentifier = "csvCluster"
        } else {
            annotationView?.markerTintColor = .systemRed
            annotationView?.glyphImage = UIImage(systemName: "mappin")
            annotationView?.clusteringIdentifier = "pinpointCluster"
        }

        let calloutView = createCustomCalloutView(for: customAnnotation)
        annotationView?.detailCalloutAccessoryView = calloutView

        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        // 1) 우리가 만든 OfflineOverlay
        if let offlineOverlay = overlay as? OfflineOverlay,
           let image = UIImage(contentsOfFile: getOfflineMapsDirectory().appendingPathComponent("\(offlineOverlay.offlineMapName).png").path) {
            return OfflineOverlayRenderer(overlay: offlineOverlay, overlayImage: image)
        }
        // 2) Polyline 예시
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .blue
            renderer.lineWidth = 3.0
            return renderer
        }
        // 3) Polygon 예시
        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.strokeColor = .red
            renderer.fillColor = UIColor.red.withAlphaComponent(0.3)
            renderer.lineWidth = 2.0
            return renderer
        }
        // 기타
        return MKOverlayRenderer(overlay: overlay)
    }
}

// MARK: - UISearchBarDelegate
extension MapViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let query = searchBar.text, !query.isEmpty {
            searchCompleter.queryFragment = query
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            searchResults.removeAll()
            tableView.reloadData()
            tableView.isHidden = true
        } else {
            searchCompleter.queryFragment = searchText
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension MapViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
        tableView.reloadData()
        tableView.isHidden = searchResults.isEmpty
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Autocomplete failed: \(error.localizedDescription)")
        showAlert(title: "Autocomplete Failed", message: error.localizedDescription)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension MapViewController: UITableViewDelegate, UITableViewDataSource {
    
    // 테이블뷰가 여러 개 있으므로, searchResults 테이블 / offlineMaps 테이블 구분
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView {
        case self.tableView: // 검색결과 테이블
            return searchResults.count
        case self.offlineMapsTableView: // 오프라인 맵 목록 테이블
            return offlineMaps.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch tableView {
        case self.tableView: // 검색결과 테이블
            let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
            let result = searchResults[indexPath.row]
            cell.textLabel?.text = result.title
            return cell

        case self.offlineMapsTableView:
            // 1) 커스텀 셀로 dequeue
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "OfflineMapCell", for: indexPath) as? OfflineMapCell else {
                return UITableViewCell()
            }
            
            let offlineMap = offlineMaps[indexPath.row]
            // 2) 현재 '활성화된' 맵인지 확인 → currentOfflineOverlay?.offlineMapName과 비교
            let isActive = (offlineMap.mapName == currentOfflineOverlay?.offlineMapName)
            
            // 3) 커스텀 셀 구성
            cell.configure(with: offlineMap, isActive: isActive)
            
            return cell

        default:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView {
        case self.tableView:
            let completion = searchResults[indexPath.row]
            let searchRequest = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: searchRequest)
            search.start { [weak self] response, error in
                guard let self = self else { return }
                tableView.deselectRow(at: indexPath, animated: true)

                if let error = error {
                    print("Search failed: \(error.localizedDescription)")
                    self.showAlert(title: "Search Failed", message: error.localizedDescription)
                    return
                }

                guard let response = response, !response.mapItems.isEmpty else {
                    self.showAlert(title: "Search Results", message: "No results found.")
                    return
                }

                for item in response.mapItems {
                    if let coordinate = item.placemark.location?.coordinate {
                        self.createPinpoint(at: coordinate)
                    }
                }
                if let firstItem = response.mapItems.first,
                   let coordinate = firstItem.placemark.location?.coordinate {
                    self.mapView.setRegion(
                        MKCoordinateRegion(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000),
                        animated: true
                    )
                }
                self.searchResults.removeAll()
                self.tableView.reloadData()
                self.tableView.isHidden = true
            }

        case self.offlineMapsTableView:
            let offlineMap = offlineMaps[indexPath.row]
            tableView.deselectRow(at: indexPath, animated: true)
            // (5) Overlay, Rename, Delete 액션
            showOfflineMapActionSheet(for: offlineMap)

        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // offlineMapsTableView라면 100px
        if tableView == self.offlineMapsTableView {
            return 120
        }
        // 검색결과 테이블은 기본값(또는 원하는 값)으로
        return 44
    }
}

// MARK: - UserDefaults Key
extension UserDefaults {
    struct OfflineMapKeys {
        static let centerLat = "OfflineMapCenterLat"
        static let centerLon = "OfflineMapCenterLon"
        static let latSpan   = "OfflineMapLatSpan"
        static let lonSpan   = "OfflineMapLonSpan"
    }
}

extension MKMapType {
    func toString() -> String {
        switch self {
        case .standard:
            return "Standard"
        case .satellite:
            return "Satellite"
        case .hybrid:
            return "Hybrid"
        case .satelliteFlyover:
            return "Satellite Flyover"
        case .hybridFlyover:
            return "Hybrid Flyover"
        default:
            return "Unknown"
        }
    }
}

// MARK: - OfflineOverlay
class OfflineOverlay: NSObject, MKOverlay {
    let boundingMapRect: MKMapRect
    let coordinate: CLLocationCoordinate2D
    
    var offlineMapName: String = ""

    init(boundingMapRect: MKMapRect, coordinate: CLLocationCoordinate2D) {
        self.boundingMapRect = boundingMapRect
        self.coordinate = coordinate
        super.init()
    }
}

// MARK: - OfflineOverlayRenderer
class OfflineOverlayRenderer: MKOverlayRenderer {
    let overlayImage: UIImage

    init(overlay: MKOverlay, overlayImage: UIImage) {
        self.overlayImage = overlayImage
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let offlineOverlay = self.overlay as? OfflineOverlay else { return }
        let overlayRect = self.rect(for: offlineOverlay.boundingMapRect)

        context.saveGState()
        context.translateBy(x: overlayRect.origin.x, y: overlayRect.origin.y)
        context.scaleBy(
            x: overlayRect.size.width / overlayImage.size.width,
            y: overlayRect.size.height / overlayImage.size.height
        )
        UIGraphicsPushContext(context)
        overlayImage.draw(at: .zero)
        UIGraphicsPopContext()
        context.restoreGState()
    }
}

class OfflineMapCell: UITableViewCell {

    private let thumbnailImageView = UIImageView()
    private let statusIndicatorView = UIView()
    
    // (1) 기존 nameLabel → 오프라인 맵 이름 + (맵타입)
    private let nameLabel = UILabel()
    
    // (2) 새로 추가: 날짜/시간 표시
    private let dateLabel = UILabel()
    
    // 수직 스택으로 nameLabel / dateLabel 배치
    private let labelStackView = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        thumbnailImageView.contentMode = .scaleAspectFit
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.font = UIFont.systemFont(ofSize: 14)
        dateLabel.textColor = .darkGray
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        labelStackView.axis = .vertical
        labelStackView.spacing = 4
        labelStackView.translatesAutoresizingMaskIntoConstraints = false

        labelStackView.addArrangedSubview(nameLabel)
        labelStackView.addArrangedSubview(dateLabel)

        statusIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        statusIndicatorView.layer.cornerRadius = 7.5
        statusIndicatorView.layer.masksToBounds = false
        statusIndicatorView.layer.shadowOffset = .zero
        statusIndicatorView.layer.shadowRadius = 5
        statusIndicatorView.layer.shadowOpacity = 1.0
        
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(labelStackView)
        contentView.addSubview(statusIndicatorView)

        NSLayoutConstraint.activate([
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            thumbnailImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 100),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 100),

            labelStackView.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 10),
            labelStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            statusIndicatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            statusIndicatorView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusIndicatorView.widthAnchor.constraint(equalToConstant: 15),
            statusIndicatorView.heightAnchor.constraint(equalToConstant: 15)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with offlineMap: OfflineMapInfo, isActive: Bool) {

        nameLabel.text = offlineMap.mapName

        if let image = UIImage(contentsOfFile: offlineMap.fileURL.path) {
            thumbnailImageView.image = image
        } else {
            thumbnailImageView.image = UIImage(systemName: "map")
        }

        if let creationDate = offlineMap.fileCreatedAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateLabel.text = formatter.string(from: creationDate)
        } else {
            dateLabel.text = ""
        }

        if isActive {
            statusIndicatorView.backgroundColor = .green
            statusIndicatorView.layer.shadowColor = UIColor.green.cgColor
        } else {
            statusIndicatorView.backgroundColor = .red
            statusIndicatorView.layer.shadowColor = UIColor.red.cgColor
        }
    }
}
