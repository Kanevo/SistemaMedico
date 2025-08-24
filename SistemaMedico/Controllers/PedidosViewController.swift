import UIKit
import CoreData
import FirebaseFirestore

class PedidosViewController: UIViewController {
    
    // MARK: - Outlets - MANTENEMOS CONEXIONES ORIGINALES
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    // MARK: - Propiedades
    private let coreDataManager = CoreDataManager.shared
    private let firebaseService = FirebaseService.shared // ✅ AGREGADO Firebase
    private var pedidos: [NSManagedObject] = []
    private var pedidosFiltrados: [NSManagedObject] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurarUI()
        configurarTableView()
        configurarSegmentedControl()
        configurarObservers()
        cargarPedidos()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cargarPedidos()
    }
    
    // MARK: - NotificationCenter
    private func configurarObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pedidosActualizados),
            name: .pedidosActualizados,
            object: nil
        )
    }
    
    @objc private func pedidosActualizados() {
        DispatchQueue.main.async {
            self.cargarPedidos()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuración
    private func configurarUI() {
        title = "Pedidos"
        
        // ✅ CORREGIDO: Botón de regreso al menú
        let btnBack = UIBarButtonItem(
            title: "🏠 Menú",
            style: .plain,
            target: self,
            action: #selector(regresarAlMenu)
        )
        
        // ✅ NUEVO: Botón de sincronización de pedidos
        let btnSync = UIBarButtonItem(
            title: "☁️ Sync",
            style: .plain,
            target: self,
            action: #selector(sincronizarPedidosEnviados)
        )
        
        // ✅ Botón para agregar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(crearNuevoPedido)
        )
        
        // ✅ CORREGIDO: Colocar ambos botones en la izquierda
        navigationItem.leftBarButtonItems = [btnBack, btnSync]
    }
    
    private func configurarTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CeldaPedido")
    }
    
    private func configurarSegmentedControl() {
        segmentedControl.removeAllSegments()
        segmentedControl.insertSegment(withTitle: "Todos", at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: "Pendientes", at: 1, animated: false)
        segmentedControl.insertSegment(withTitle: "Enviados", at: 2, animated: false)
        segmentedControl.insertSegment(withTitle: "Entregados", at: 3, animated: false)
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(cambioSegmento), for: .valueChanged)
    }
    
    // MARK: - Acciones
    @objc private func regresarAlMenu() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func crearNuevoPedido() {
        let storyboard = UIStoryboard(name: "Pedidos", bundle: nil)
        if let crearPedidoVC = storyboard.instantiateViewController(withIdentifier: "CrearPedidoViewController") as? CrearPedidoViewController {
            let navController = UINavigationController(rootViewController: crearPedidoVC)
            present(navController, animated: true)
        }
    }
    
    @objc private func cambioSegmento() {
        filtrarPedidos()
    }
    
    // ✅ NUEVO: Sincronización manual de pedidos enviados
    @objc private func sincronizarPedidosEnviados() {
        let pedidosEnviados = pedidos.filter { pedido in
            let estado = pedido.value(forKey: "estado") as? String ?? ""
            return estado == "Enviado" || estado == "Entregado"
        }
        
        if pedidosEnviados.isEmpty {
            mostrarError("No hay pedidos enviados para sincronizar")
            return
        }
        
        mostrarIndicadorSync(true)
        
        firebaseService.sincronizarPedidosEnviados(pedidosLocales: pedidosEnviados) { [weak self] result in
            DispatchQueue.main.async {
                self?.mostrarIndicadorSync(false)
                
                switch result {
                case .success(let mensaje):
                    self?.mostrarExito(mensaje)
                case .failure(let error):
                    self?.mostrarError("Error al sincronizar: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func mostrarIndicadorSync(_ mostrar: Bool) {
        if let btnSync = navigationItem.leftBarButtonItems?.last {
            btnSync.isEnabled = !mostrar
            btnSync.title = mostrar ? "⏳" : "☁️ Sync"
        }
    }
    
    private func filtrarPedidos() {
        switch segmentedControl.selectedSegmentIndex {
        case 1: // Pendientes
            pedidosFiltrados = pedidos.filter {
                ($0.value(forKey: "estado") as? String) == "Pendiente"
            }
        case 2: // Enviados
            pedidosFiltrados = pedidos.filter {
                ($0.value(forKey: "estado") as? String) == "Enviado"
            }
        case 3: // Entregados
            pedidosFiltrados = pedidos.filter {
                ($0.value(forKey: "estado") as? String) == "Entregado"
            }
        default:
            pedidosFiltrados = pedidos
        }
        
        tableView.reloadData()
    }
    
    // MARK: - Métodos
    private func cargarPedidos() {
        pedidos = coreDataManager.obtenerPedidos()
        filtrarPedidos()
    }
    
    private func mostrarDetallePedido(_ pedido: NSManagedObject) {
        let storyboard = UIStoryboard(name: "Pedidos", bundle: nil)
        if let detalleVC = storyboard.instantiateViewController(withIdentifier: "DetallePedidoViewController") as? DetallePedidoViewController {
            detalleVC.pedido = pedido
            navigationController?.pushViewController(detalleVC, animated: true)
        }
    }
    
    // ✅ MODIFICADO: Cambiar estado con sincronización universal automática
    private func cambiarEstadoPedido(_ pedido: NSManagedObject) {
        let estadoActual = pedido.value(forKey: "estado") as? String ?? "Pendiente"
        let cliente = pedido.value(forKey: "cliente") as? String ?? "Cliente"
        
        let alert = UIAlertController(
            title: "Cambiar Estado",
            message: "Pedido de: \(cliente)\nEstado actual: \(estadoActual)",
            preferredStyle: .actionSheet
        )
        
        // Opciones de estado según el estado actual
        if estadoActual == "Pendiente" {
            alert.addAction(UIAlertAction(title: "📤 Marcar como Enviado", style: .default) { _ in
                self.actualizarEstadoPedido(pedido, nuevoEstado: "Enviado", conSincronizacion: true)
            })
            
            alert.addAction(UIAlertAction(title: "✅ Marcar como Entregado", style: .default) { _ in
                self.actualizarEstadoPedido(pedido, nuevoEstado: "Entregado", conSincronizacion: true)
            })
        } else if estadoActual == "Enviado" {
            alert.addAction(UIAlertAction(title: "✅ Marcar como Entregado", style: .default) { _ in
                self.actualizarEstadoPedido(pedido, nuevoEstado: "Entregado", conSincronizacion: true)
            })
            
            alert.addAction(UIAlertAction(title: "⏪ Regresar a Pendiente", style: .default) { _ in
                self.actualizarEstadoPedido(pedido, nuevoEstado: "Pendiente", conSincronizacion: false)
            })
        } else if estadoActual == "Entregado" {
            alert.addAction(UIAlertAction(title: "⏪ Regresar a Enviado", style: .default) { _ in
                self.actualizarEstadoPedido(pedido, nuevoEstado: "Enviado", conSincronizacion: true)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }
    
    // ✅ NUEVO: Actualizar estado con sincronización automática a Firebase
    private func actualizarEstadoPedido(_ pedido: NSManagedObject, nuevoEstado: String, conSincronizacion: Bool) {
        let cliente = pedido.value(forKey: "cliente") as? String ?? "Cliente"
        
        // Mostrar indicador en la celda
        mostrarIndicadorEnCelda(pedido, mostrar: true)
        
        // 1. Actualizar en CoreData
        coreDataManager.actualizarEstadoPedido(pedido: pedido, estado: nuevoEstado)
        
        if conSincronizacion && (nuevoEstado == "Enviado" || nuevoEstado == "Entregado") {
            // 2. ✅ SINCRONIZAR AUTOMÁTICAMENTE CON FIREBASE SIN DUPLICADOS
            firebaseService.actualizarEstadoPedido(pedidoLocal: pedido, nuevoEstado: nuevoEstado) { [weak self] result in
                DispatchQueue.main.async {
                    self?.mostrarIndicadorEnCelda(pedido, mostrar: false)
                    
                    switch result {
                    case .success(let mensaje):
                        print("✅ Estado actualizado en Firebase: \(mensaje)")
                        self?.mostrarNotificacionTemporal("📤 Pedido de \(cliente) actualizado en Firebase")
                        
                    case .failure(let error):
                        print("⚠️ Estado actualizado localmente pero fallo en Firebase: \(error.localizedDescription)")
                        self?.mostrarNotificacionTemporal("⚠️ Estado actualizado localmente. Sincronización pendiente.")
                    }
                    
                    // 3. Actualizar UI y notificar
                    self?.cargarPedidos()
                    NotificationCenter.default.post(name: .pedidosActualizados, object: pedido)
                }
            }
        } else {
            // Solo cambio local
            mostrarIndicadorEnCelda(pedido, mostrar: false)
            cargarPedidos()
            NotificationCenter.default.post(name: .pedidosActualizados, object: pedido)
            mostrarNotificacionTemporal("✅ Estado actualizado localmente")
        }
    }
    
    private func eliminarPedido(_ pedido: NSManagedObject) {
        let cliente = pedido.value(forKey: "cliente") as? String ?? ""
        let estado = pedido.value(forKey: "estado") as? String ?? ""
        
        let alert = UIAlertController(
            title: "Eliminar Pedido",
            message: "¿Eliminar pedido de '\(cliente)'?\n\nEsto restaurará el stock de los productos.",
            preferredStyle: .alert
        )
        
        // Solo permitir eliminar pedidos no entregados
        if estado == "Entregado" {
            alert.message = "No se pueden eliminar pedidos ya entregados."
            alert.addAction(UIAlertAction(title: "OK", style: .default))
        } else {
            alert.addAction(UIAlertAction(title: "Eliminar", style: .destructive) { _ in
                self.coreDataManager.eliminarPedido(pedido)
                self.cargarPedidos()
                self.mostrarExito("✅ Pedido eliminado y stock restaurado")
                
                // NotificationCenter
                NotificationCenter.default.post(name: .pedidosActualizados, object: nil)
                NotificationCenter.default.post(name: .productosActualizados, object: nil)
            })
            
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        }
        
        present(alert, animated: true)
    }
    
    // ✅ NUEVO: Indicador visual en celda específica
    private func mostrarIndicadorEnCelda(_ pedido: NSManagedObject, mostrar: Bool) {
        // Encontrar la celda del pedido y mostrar indicador
        if let index = pedidosFiltrados.firstIndex(of: pedido) {
            let indexPath = IndexPath(row: index, section: 0)
            if let cell = tableView.cellForRow(at: indexPath) {
                if mostrar {
                    cell.accessoryView = {
                        let activity = UIActivityIndicatorView(style: .medium)
                        activity.startAnimating()
                        return activity
                    }()
                } else {
                    cell.accessoryView = nil
                    cell.accessoryType = .disclosureIndicator
                }
            }
        }
    }
    
    // ✅ NUEVO: Notificación temporal no intrusiva
    private func mostrarNotificacionTemporal(_ mensaje: String) {
        let alert = UIAlertController(title: nil, message: mensaje, preferredStyle: .alert)
        present(alert, animated: true)
        
        // Auto-cerrar después de 2 segundos
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            alert.dismiss(animated: true)
        }
    }
    
    // MARK: - UI Helpers
    private func mostrarError(_ mensaje: String) {
        let alert = UIAlertController(title: "Error", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func mostrarExito(_ mensaje: String) {
        let alert = UIAlertController(title: "✅ Éxito", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension PedidosViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pedidosFiltrados.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CeldaPedido", for: indexPath)
        let pedido = pedidosFiltrados[indexPath.row]
        
        let cliente = pedido.value(forKey: "cliente") as? String ?? ""
        let destino = pedido.value(forKey: "destino") as? String ?? ""
        let total = pedido.value(forKey: "total") as? Double ?? 0.0
        let estado = pedido.value(forKey: "estado") as? String ?? ""
        let fecha = pedido.value(forKey: "fechaCreacion") as? Date ?? Date()
        
        var configuracion = cell.defaultContentConfiguration()
        configuracion.text = "\(cliente) - \(destino)"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        configuracion.secondaryText = "S/. \(String(format: "%.2f", total)) | \(formatter.string(from: fecha))"
        
        // ✅ Iconos y colores según estado
        switch estado {
        case "Pendiente":
            configuracion.text = "⏳ " + configuracion.text!
            cell.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.1)
        case "Enviado":
            configuracion.text = "📤 " + configuracion.text!
            cell.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        case "Entregado":
            configuracion.text = "✅ " + configuracion.text!
            cell.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        default:
            cell.backgroundColor = UIColor.systemBackground
        }
        
        cell.contentConfiguration = configuracion
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension PedidosViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let pedido = pedidosFiltrados[indexPath.row]
        mostrarDetallePedido(pedido)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let pedido = pedidosFiltrados[indexPath.row]
        let estado = pedido.value(forKey: "estado") as? String ?? ""
        
        var acciones: [UIContextualAction] = []
        
        // Acción de cambiar estado
        let accionEstado = UIContextualAction(style: .normal, title: "Estado") { _, _, completion in
            self.cambiarEstadoPedido(pedido)
            completion(true)
        }
        accionEstado.backgroundColor = .systemBlue
        acciones.append(accionEstado)
        
        // Acción de eliminar (solo si no está entregado)
        if estado != "Entregado" {
            let accionEliminar = UIContextualAction(style: .destructive, title: "Eliminar") { _, _, completion in
                self.eliminarPedido(pedido)
                completion(true)
            }
            acciones.append(accionEliminar)
        }
        
        return UISwipeActionsConfiguration(actions: acciones)
    }
}
