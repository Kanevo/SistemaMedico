import UIKit
import CoreData
import FirebaseFirestore

class PedidosViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    // MARK: - Propiedades
    private let coreDataManager = CoreDataManager.shared
    private var pedidos: [NSManagedObject] = []
    private var pedidosFiltrados: [NSManagedObject] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurarUI()
        configurarTableView()
        configurarSegmentedControl()
        configurarObservers() // ← NotificationCenter
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
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(crearNuevoPedido)
        )
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
    
    @objc private func filtrarPedidos() {
        let indiceSeleccionado = segmentedControl.selectedSegmentIndex
        
        switch indiceSeleccionado {
        case 0: // Todos
            pedidosFiltrados = pedidos
        case 1: // Pendientes
            pedidosFiltrados = pedidos.filter { pedido in
                (pedido.value(forKey: "estado") as? String) == "Pendiente"
            }
        case 2: // Enviados
            pedidosFiltrados = pedidos.filter { pedido in
                (pedido.value(forKey: "estado") as? String) == "Enviado"
            }
        case 3: // Entregados
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
    
    private func cambiarEstadoPedido(_ pedido: NSManagedObject) {
        let estadoActual = pedido.value(forKey: "estado") as? String ?? "Pendiente"
        
        let alert = UIAlertController(title: "Cambiar Estado", message: "Estado actual: \(estadoActual)", preferredStyle: .actionSheet)
        
        let estados = ["Pendiente", "Preparando", "Enviado", "Entregado", "Cancelado"]
        
        for estado in estados {
            if estado != estadoActual {
                alert.addAction(UIAlertAction(title: estado, style: .default) { _ in
                    self.coreDataManager.actualizarEstadoPedido(pedido: pedido, estado: estado)
                    self.cargarPedidos()
                    
                    // NotificationCenter
                    NotificationCenter.default.post(name: .pedidosActualizados, object: nil)
                    
                    // ✅ FIREBASE: Solo cuando cambia a "Enviado"
                    if estado == "Enviado" {
                        self.enviarPedidoFirebase(pedido)
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
    
    // ✅ FIREBASE: Enviar pedido cuando estado = "Enviado"
    private func enviarPedidoFirebase(_ pedido: NSManagedObject) {
        let cliente = pedido.value(forKey: "cliente") as? String ?? ""
        let destino = pedido.value(forKey: "destino") as? String ?? ""
        let total = pedido.value(forKey: "total") as? Double ?? 0.0
        
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
        
        let pedidoAPI = PedidoAPI(cliente: cliente, destino: destino, productos: productos, total: total)
        
        // ✅ USAR FIREBASE
        FirebaseService.shared.enviarPedido(pedido: pedidoAPI) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let mensaje):
                    self?.mostrarExito("✅ Pedido médico enviado a Firebase: \(mensaje)")
                    
                    // NotificationCenter
                    NotificationCenter.default.post(name: .pedidoEnviado, object: pedido)
                    
                case .failure(let error):
                    self?.mostrarError("Error al enviar a Firebase: \(error.localizedDescription)")
                }
            }
        }
    }
    
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
        
        if let fecha = pedido.value(forKey: "fechaCreacion") as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            
            cell.textLabel?.text = "\(cliente) - \(destino)"
            cell.detailTextLabel?.text = "\(estado) • S/. \(String(format: "%.2f", total)) • \(formatter.string(from: fecha))"
        }
        
        // Configurar color según estado
        switch estado {
        case "Pendiente":
            cell.textLabel?.textColor = .systemOrange
        case "Preparando":
            cell.textLabel?.textColor = .systemBlue
        case "Enviado":
            cell.textLabel?.textColor = .systemPurple
        case "Entregado":
            cell.textLabel?.textColor = .systemGreen
        case "Cancelado":
            cell.textLabel?.textColor = .systemRed
        default:
            cell.textLabel?.textColor = .label
        }
        
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
        
        // Acción: Cambiar Estado
        let cambiarEstado = UIContextualAction(style: .normal, title: "Estado") { _, _, completion in
            self.cambiarEstadoPedido(pedido)
            completion(true)
        }
        cambiarEstado.backgroundColor = .systemBlue
        
        // Acción Eliminar
        let eliminarPedido = UIContextualAction(style: .destructive, title: "Eliminar") { _, _, completion in
            self.mostrarConfirmacionEliminarPedido(pedido: pedido)
            completion(true)
        }
        eliminarPedido.backgroundColor = .systemRed
        
        return UISwipeActionsConfiguration(actions: [eliminarPedido, cambiarEstado])
    }
}
