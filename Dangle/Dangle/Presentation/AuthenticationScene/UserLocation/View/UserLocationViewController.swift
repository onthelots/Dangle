//
//  UserLocationViewController.swift
//  Dangle
//
//  Created by Jae hyuk Yim on 2023/08/08.
//

import UIKit
import Combine
import CoreLocation

class UserLocationViewController: UIViewController, UISearchResultsUpdating, UISearchBarDelegate {


    // ViewModel을 프로퍼티로 선언하고 주입합니다.
    let viewModel: UserLocationViewModel!
    private let coreLocationService = CoreLocationService()

    private var userlocation: [Regcode] = []
    private var subscription =  Set<AnyCancellable>()

    // MARK: - Components (Views)

    // searchController
    let searchController: UISearchController = {
        let searchBar = UISearchController()
        searchBar.searchBar.placeholder = "동, 읍을 입력해주세요 (ex. 역삼동)"
        searchBar.searchBar.searchBarStyle = .minimal
        searchBar.definesPresentationContext = true
        return searchBar
    }()

    // 결과를 보여주는 테이블 뷰
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(
            UserLocationTableViewCell.self,
            forCellReuseIdentifier: UserLocationTableViewCell.identifier
        )
        tableView.isHidden = true
        return tableView
    }()

    // 위치 권한이 거부된 경우 보여주는 뷰
    private let locationAuthDisallowedView = LocationAuthDisallowedView()

    // 초기화
    init(viewModel: UserLocationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ViewDidLoad()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "위치찾기"
        view.backgroundColor = .systemBackground
        coreLocationService.delegate = self
        setUplocationAuthDisallowedView()

        // 테이블 뷰 추가 및 델리게이트 설정
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self

        viewModel.$userLocation
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.userlocation = items
                self?.tableView.reloadData()
            }.store(in: &subscription)

        // ViewModel에서 데이터를 가져오도록 호출
        coreLocationService.checkUserDeviceLocationServicesAuthorization()

        // search Results update
        searchController.searchResultsUpdater = self

        // searchBar
        searchController.searchBar.delegate = self

        // configure navigationItem SearchController
        navigationItem.searchController = searchController
    }

    func updateSearchResults(for searchController: UISearchController) {
        guard let query = searchController.searchBar.text,
              !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            userlocation = viewModel.getPreviousUserLocation()
            tableView.reloadData()
            return
        }
        locationAuthDisallowedView.isHidden = true
        tableView.isHidden = false
        viewModel.fetchUserSearchLocation(query: query) // ViewModel 실시
        tableView.reloadData()
    }

    // MARK: - View Layout
    override func viewDidLayoutSubviews() {
        locationAuthDisallowedView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            locationAuthDisallowedView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            locationAuthDisallowedView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    // 위치 권한 거부 뷰 설정
    private func setUplocationAuthDisallowedView() {
        view.addSubview(locationAuthDisallowedView)
        locationAuthDisallowedView.delegate = self
        navigationItem.searchController?.isActive = true

        locationAuthDisallowedView.configure(
            with: LocationAuthDisallowedViewModel(
                text: "현재 위치를 확인할 수 없습니다.\n주소 검색창을 통해 동네를 설정하세요.",
                actionTitle: "위치 권한 재 설정하기")
        )
    }
}

// CoreLocationServiceDelegate 델리게이트 메서드 구현
extension UserLocationViewController: CoreLocationServiceDelegate {
    func presentDisallowedView() {
        self.locationAuthDisallowedView.isHidden = false
    }

    func updateLocation(coordinate: CLLocation) {
        // viewModel에 업데이트된 위치값 전달
        viewModel.fetchUserLocation(coordinate: coordinate)
        userlocation = viewModel.userLocation
        tableView.isHidden = false
        tableView.reloadData()
        // 위치 업데이트에 필요한 작업 수행
    }

    func showLocationServiceError() {
        // 위치 서비스 오류를 처리하는 알림 뷰 표시
        let alert = UIAlertController(
            title: "위치정보 이용",
            message: "위치 서비스를 사용할 수 없습니다.\n디바이스의 '설정 > 개인정보 보호'에서 위치 서비스를 켜주세요.",
            preferredStyle: .alert
        )

        let goToSettingsAction = UIAlertAction(title: "설정으로 이동", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)

                // 🚫 한번 더 체크함
                self.coreLocationService.checkUserDeviceLocationServicesAuthorization()
            }
        }

        let cancelAction = UIAlertAction(title: "취소", style: .cancel) { _ in
        }

        alert.addAction(goToSettingsAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }

}

// LocationAuthDisallowedViewDelegate 델리게이트 메서드 구현
extension UserLocationViewController: LocationAuthDisallowedViewDelegate {
    func locationAuthDisallowedViewDidTapButton(_ view: LocationAuthDisallowedView) {
        showLocationServiceError()
    }
}

// UITableViewDelegate 및 UITableViewDataSource 메서드 구현
extension UserLocationViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userlocation.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: UserLocationTableViewCell.identifier, for: indexPath) as? UserLocationTableViewCell else {
            return UITableViewCell()
        }

        // ViewModel에서 가져온 데이터를 셀에 표시
        let address = userlocation[indexPath.row]
        cell.configure(address: address)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // 선택된 항목에 대한 처리 (예: 화면 전환)
        let address = userlocation[indexPath.row]
        print("주소가 선택되었습니다 : \(address.name)")
        print("코드도 선택되었습니다 : \(address.code)")
    }
}
