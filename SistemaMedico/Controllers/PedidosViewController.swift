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
        segmentedControl.insertSegment(withTitle: "Preparando", at: 2, animated: false)
        segmentedControl.insertSegment(withTitle: "Enviados", at: 3, animated: false)
        segmentedControl.insertSegment(withTitle: "Entregados", at: 4, animated: false)
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(filtrarPedidos), for: .valueChanged)
    }
    
    // MARK: - Acciones
    @objc private func crearNuevoPedido() {
        let storyboard = UIStoryboard(name: "Pedidos", bundle: nil)
        if let crearPedidoVC = storyboard.instantiateViewController(withIdentifier: "CrearPedidoViewController") as? CrearPedidoViewController {
            let navController = UINavigationController(rootViewController: crearPedidoVC)
            present(navController, animated: true)
        }
    }
    
    // ✅ NUEVO: Método para regresar al menú principal
    @objc private func regresarAlMenu() {
        navigationController?.popViewController(animated: true)
    }
    
    // ✅ NUEVO: Sincronizar solo pedidos enviados con Firebase
    @objc private func sincronizarPedidosEnviados() {
        // Actualizar el botón Sync específicamente
        if let leftButtons = navigationItem.leftBarButtonItems,
           leftButtons.count > 1 {
            leftButtons[1].title = "⏳ Sync..."
            leftButtons[1].isEnabled = false
        }
        
        let pedidosEnviados = pedidos.filter { pedido in
            let estado = pedido.value(forKey: "estado") as? String ?? ""
            return estado == "Enviado" || estado == "Entregado"
        }
        
        if pedidosEnviados.isEmpty {
            // Restaurar el botón Sync
            if let leftButtons = navigationItem.leftBarButtonItems,
               leftButtons.count > 1 {
                leftButtons[1].title = "☁️ Sync"
                leftButtons[1].isEnabled = true
            }
            mostrarInfo("No hay pedidos enviados para sincronizar")
            return
        }
        
        let grupo = DispatchGroup()
        var exitos = 0
        var errores = 0
        
        for pedido in pedidosEnviados {
            grupo.enter()
            enviarPedidoAFirebase(pedido) { success in
                if success {
                    exitos += 1
                } else {
                    errores += 1
                }
                grupo.leave()
            }
        }
        
        grupo.notify(queue: .main) {
            // Restaurar el botón Sync
            if let leftButtons = self.navigationItem.leftBarButtonItems,
               leftButtons.count > 1 {
                leftButtons[1].title = "☁️ Sync"
                leftButtons[1].isEnabled = true
            }
            
            if errores == 0 {
                self.mostrarExito("✅ \(exitos) pedidos sincronizados correctamente con Firebase")
            } else {
                self.mostrarError("⚠️ \(exitos) pedidos sincronizados, \(errores) con errores")
            }
        }
    }
    
    @objc private func filtrarPedidos() {
        let indiceSeleccionado = segmentedControl.selectedSegmentIndex
        
        switch indiceSeleccionado {
        case 0: // Todos
            pedidosFiltrados = pedidos
        case 1: // Pendientes
            pedidosFiltrados = pedidos.filter { pedido in
                (pedido.value(forKey: "estado") as? String) == "Pendiente"
            }
        case 2: // Preparando
            pedidosFiltrados = pedidos.filter { pedido in
                (pedido.value(forKey: "estado") as? String) == "Preparando"
            }
        case 3: // Enviados
            pedidosFiltrados = pedidos.filter { pedido in
                (pedido.value(forKey: "estado") as? String) == "Enviado"
            }
        case 4: // Entregados
            pedidosFiltrados = pedidos.filter { pedido in
                (pedido.value(forKey: "estado") as? String) == "Entregado"
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
    
    // ✅ MODIFICADO: Cambiar estado con envío automático a Firebase cuando sea "Enviado"
    private func cambiarEstadoPedido(_ pedido: NSManagedObject) {
        let estadoActual = pedido.value(forKey: "estado") as? String ?? "Pendiente"
        
        let alert = UIAlertController(title: "Cambiar Estado", message: "Estado actual: \(estadoActual)", preferredStyle: .actionSheet)
        
        let estados = ["Pendiente", "Preparando", "Enviado", "Entregado", "Cancelado"]
        
        for estado in estados {
            if estado != estadoActual {
                alert.addAction(UIAlertAction(title: estado, style: .default) { _ in
                    // Actualizar estado en CoreData
                    self.coreDataManager.actualizarEstadoPedido(pedido: pedido, estado: estado)
                    self.cargarPedidos()
                    
                    // NotificationCenter
                    NotificationCenter.default.post(name: .pedidosActualizados, object: nil)
                    
                    // ✅ NUEVO: Enviar automáticamente a Firebase cuando cambie a "Enviado"
                    if estado == "Enviado" {
                        self.mostrarIndicadorEnvio(pedido, mostrar: true)
                        self.enviarPedidoAFirebase(pedido) { [weak self] success in
                            DispatchQueue.main.async {
                                self?.mostrarIndicadorEnvio(pedido, mostrar: false)
                                if success {
                                    self?.mostrarExito("✅ Pedido enviado exitosamente a Firebase")
                                    // Notificar al menú principal
                                    NotificationCenter.default.post(name: .pedidoEnviado, object: pedido)
                                } else {
                                    self?.mostrarError("⚠️ Estado actualizado pero falló el envío a Firebase")
                                }
                            }
                        }
                    }
                })
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        // Para iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func mostrarConfirmacionEliminarPedido(pedido: NSManagedObject) {
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
    
    // ✅ NUEVO: Enviar pedido individual a Firebase
    private func enviarPedidoAFirebase(_ pedido: NSManagedObject, completion: @escaping (Bool) -> Void) {
        let cliente = pedido.value(forKey: "cliente") as? String ?? ""
        let destino = pedido.value(forKey: "destino") as? String ?? ""
        let total = pedido.value(forKey: "total") as? Double ?? 0.0
        let estado = pedido.value(forKey: "estado") as? String ?? "Pendiente"
        
        // Obtener detalles del pedido
        let detalles = coreDataManager.obtenerDetallesPedido(pedido: pedido)
        var productos: [ProductoPedidoAPI] = []
        
        for detalle in detalles {
            if let producto = detalle.value(forKey: "producto") as? NSManagedObject {
                let nombre = producto.value(forKey: "nombre") as? String ?? ""
                let precio = producto.value(forKey: "precio") as? Double ?? 0.0
                let cantidad = detalle.value(forKey: "cantidad") as? Int32 ?? 0
                
                productos.append(ProductoPedidoAPI(
                    id: Int.random(in: 1...1000),
                    nombre: nombre,
                    cantidad: Int(cantidad),
                    precio: precio
                ))
            }
        }
        
        let pedidoAPI = PedidoAPI(
            cliente: cliente,
            destino: destino,
            productos: productos,
            total: total
        )
        
        // ✅ Enviar a Firebase con el estado actual
        firebaseService.enviarPedido(pedido: pedidoAPI) { result in
            switch result {
            case .success(_):
                completion(true)
            case .failure(let error):
                print("❌ Error enviando pedido a Firebase: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // ✅ NUEVO: Indicador visual mientras se envía
    private func mostrarIndicadorEnvio(_ pedido: NSManagedObject, mostrar: Bool) {
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
    
    // MARK: - UI Helpers
    private func mostrarError(_ mensaje: String) {
        let alert = UIAlertController(title: "Error", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func mostrarExito(_ mensaje: String) {
        let alert = UIAlertController(title: "Éxito", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func mostrarInfo(_ mensaje: String) {
        let alert = UIAlertController(title: "Información", message: mensaje, preferredStyle: .alert)
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
        
        // Formatter para fecha
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        // Configurar texto principal
        cell.textLabel?.text = "👤 \(cliente)"
        cell.detailTextLabel?.text = "📍 \(destino) • 💰 S/. \(String(format: "%.2f", total)) • 📅 \(formatter.string(from: fecha))"
        
        // ✅ NUEVO: Configurar color según estado del pedido
        switch estado {
        case "Pendiente":
            cell.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.1)
            cell.textLabel?.textColor = .systemOrange
        case "Preparando":
            cell.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            cell.textLabel?.textColor = .systemBlue
        case "Enviado":
            cell.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
            cell.textLabel?.textColor = .systemPurple
        case "Entregado":
            cell.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
            cell.textLabel?.textColor = .systemGreen
        case "Cancelado":
            cell.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            cell.textLabel?.textColor = .systemRed
        default:
            cell.backgroundColor = .systemBackground
            cell.textLabel?.textColor = .label
        }
        
        // Agregar etiqueta de estado
        cell.detailTextLabel?.text! += " • 📋 \(estado)"
        cell.detailTextLabel?.textColor = cell.textLabel?.textColor
        
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension PedidosViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let pedido = pedidosFiltrados[indexPath.row]
        
        let alert = UIAlertController(title: "Opciones del Pedido", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "👁️ Ver Detalle", style: .default) { _ in
            self.mostrarDetallePedido(pedido)
        })
        
        alert.addAction(UIAlertAction(title: "🔄 Cambiar Estado", style: .default) { _ in
            self.cambiarEstadoPedido(pedido)
        })
        
        let estado = pedido.value(forKey: "estado") as? String ?? ""
        if estado != "Entregado" {
            alert.addAction(UIAlertAction(title: "🗑️ Eliminar", style: .destructive) { _ in
                self.mostrarConfirmacionEliminarPedido(pedido: pedido)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        // Para iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: indexPath)
        }
        
        present(alert, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}
