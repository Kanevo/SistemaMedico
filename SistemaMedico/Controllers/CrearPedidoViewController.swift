import UIKit
import CoreData

class CrearPedidoViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var txtCliente: UITextField!
    @IBOutlet weak var pickerDestino: UIPickerView!
    @IBOutlet weak var tableViewProductos: UITableView!
    @IBOutlet weak var lblTotal: UILabel!
    @IBOutlet weak var btnCrearPedido: UIButton!
    
    // MARK: - Propiedades
    private let coreDataManager = CoreDataManager.shared
    private let firebaseService = FirebaseService.shared // ✅ AGREGADO: Firebase service
    private let destinos = ["Lima", "Arequipa", "Trujillo", "Chiclayo", "Piura", "Iquitos", "Cusco", "Huancayo", "Chimbote", "Tacna"]
    private var destinoSeleccionado = "Lima"
    private var productos: [NSManagedObject] = []
    private var productosSeleccionados: [(producto: NSManagedObject, cantidad: Int)] = []
    private var totalPedido: Double = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurarUI()
        configurarTableView()
        configurarPicker()
        cargarProductos()
        actualizarTotal()
    }
    
    // MARK: - Configuración
    private func configurarUI() {
        title = "Nuevo Pedido"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelar)
        )
        
        txtCliente.placeholder = "Nombre del cliente"
        
        btnCrearPedido.backgroundColor = .systemGreen
        btnCrearPedido.setTitleColor(.white, for: .normal)
        btnCrearPedido.layer.cornerRadius = 10
        btnCrearPedido.setTitle("Crear Pedido", for: .normal)
    }
    
    private func configurarTableView() {
        tableViewProductos.delegate = self
        tableViewProductos.dataSource = self
        tableViewProductos.register(UITableViewCell.self, forCellReuseIdentifier: "CeldaProducto")
    }
    
    private func configurarPicker() {
        pickerDestino.delegate = self
        pickerDestino.dataSource = self
    }
    
    // MARK: - Acciones
    @objc private func cancelar() {
        dismiss(animated: true)
    }
    
    // ✅ ACTUALIZADO: Crear pedido con stock automático + envío a Firebase inmediato
    @IBAction func crearPedido(_ sender: UIButton) {
        guard validarDatos() else { return }
        
        let cliente = txtCliente.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // ✅ Indicador visual mientras se crea y envía
        mostrarIndicadorCreacion(true)
        
        // ✅ 1. Crear el pedido local (esto ya descuenta automáticamente el stock)
        let pedido = coreDataManager.crearPedido(cliente: cliente, destino: destinoSeleccionado, total: totalPedido)
        
        // ✅ 2. Agregar los productos al pedido (descuenta stock automáticamente)
        var productosParaAPI: [ProductoPedidoAPI] = []
        
        for item in productosSeleccionados {
            if item.cantidad > 0 {
                // Agregar detalle (esto descuenta stock automáticamente)
                coreDataManager.agregarDetallePedido(
                    pedido: pedido,
                    producto: item.producto,
                    cantidad: Int32(item.cantidad)
                     
                )
                
                // Preparar para Firebase
                let nombre = item.producto.value(forKey: "nombre") as? String ?? ""
                let precio = item.producto.value(forKey: "precio") as? Double ?? 0.0
                
                productosParaAPI.append(ProductoPedidoAPI(
                    id: Int.random(in: 1...1000),
                    nombre: nombre,
                    cantidad: item.cantidad,
                    precio: precio
                ))
            }
        }
        
        // ✅ 3. Crear objeto PedidoAPI para Firebase
        let pedidoAPI = PedidoAPI(
            cliente: cliente,
            destino: destinoSeleccionado,
            productos: productosParaAPI,
            total: totalPedido
        )
        
        // ✅ 4. ENVÍO AUTOMÁTICO A FIREBASE - Sin duplicados
        firebaseService.sincronizarPedidoUniversal(pedido: pedidoAPI, pedidoLocal: pedido) { [weak self] result in
            DispatchQueue.main.async {
                self?.mostrarIndicadorCreacion(false)
                
                switch result {
                case .success(let mensaje):
                    print("✅ Pedido enviado automáticamente a Firebase: \(mensaje)")
                    
                    // ✅ 5. Mostrar éxito y notificar cambios
                    self?.mostrarExito("✅ Pedido creado y enviado a Firebase automáticamente\n\n• Stock descontado\n• Sincronizado con la nube") {
                        // ✅ Notificar actualización automática
                        NotificationCenter.default.post(name: .pedidosActualizados, object: pedido)
                        NotificationCenter.default.post(name: .productosActualizados, object: nil) // Stock actualizado
                        
                        self?.dismiss(animated: true)
                    }
                    
                case .failure(let error):
                    // Pedido local creado exitosamente, pero fallo el envío a Firebase
                    print("⚠️ Pedido creado localmente pero fallo envío a Firebase: \(error.localizedDescription)")
                    
                    self?.mostrarAdvertencia("⚠️ Pedido creado exitosamente\n\nEl pedido se guardó localmente y el stock fue descontado, pero no se pudo enviar automáticamente a Firebase. Podrá sincronizarlo manualmente después.") {
                        // Notificar cambios locales
                        NotificationCenter.default.post(name: .pedidosActualizados, object: pedido)
                        NotificationCenter.default.post(name: .productosActualizados, object: nil)
                        
                        self?.dismiss(animated: true)
                    }
                }
            }
        }
    }
    
    // ✅ NUEVO: Indicador visual durante creación
    private func mostrarIndicadorCreacion(_ mostrar: Bool) {
        if mostrar {
            btnCrearPedido.setTitle("📤 Creando y enviando...", for: .normal)
            btnCrearPedido.isEnabled = false
            
            // Mostrar activity indicator
            let activityIndicator = UIActivityIndicatorView(style: .medium)
            activityIndicator.color = .white
            activityIndicator.startAnimating()
            
            btnCrearPedido.addSubview(activityIndicator)
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                activityIndicator.trailingAnchor.constraint(equalTo: btnCrearPedido.trailingAnchor, constant: -20),
                activityIndicator.centerYAnchor.constraint(equalTo: btnCrearPedido.centerYAnchor)
            ])
            
            btnCrearPedido.tag = 999 // Para encontrar el indicator después
        } else {
            btnCrearPedido.setTitle("Crear Pedido", for: .normal)
            btnCrearPedido.isEnabled = true
            
            // Remover activity indicator
            if let indicator = btnCrearPedido.viewWithTag(999) {
                indicator.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Métodos
    private func cargarProductos() {
        productos = coreDataManager.obtenerProductos()
        
        // Inicializar productos seleccionados con cantidad 0
        productosSeleccionados = productos.map { ($0, 0) }
        
        tableViewProductos.reloadData()
    }
    
    private func actualizarTotal() {
        totalPedido = 0.0
        
        for item in productosSeleccionados {
            if item.cantidad > 0 {
                let precio = item.producto.value(forKey: "precio") as? Double ?? 0.0
                totalPedido += precio * Double(item.cantidad)
            }
        }
        
        lblTotal.text = "Total: S/. \(String(format: "%.2f", totalPedido))"
    }
    
    private func validarDatos() -> Bool {
        // Validar cliente
        guard let cliente = txtCliente.text, !cliente.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            mostrarError("Por favor ingrese el nombre del cliente")
            return false
        }
        
        // Validar que haya al menos un producto seleccionado
        let tieneProductos = productosSeleccionados.contains { $0.cantidad > 0 }
        guard tieneProductos else {
            mostrarError("Por favor seleccione al menos un producto")
            return false
        }
        
        // Validar stock disponible
        for item in productosSeleccionados {
            if item.cantidad > 0 {
                let stockDisponible = item.producto.value(forKey: "stock") as? Int32 ?? 0
                if Int32(item.cantidad) > stockDisponible {
                    let nombre = item.producto.value(forKey: "nombre") as? String ?? ""
                    mostrarError("Stock insuficiente para \(nombre). Disponible: \(stockDisponible)")
                    return false
                }
            }
        }
        
        return true
    }
    
    private func mostrarSeleccionCantidad(paraProducto producto: NSManagedObject, enIndice indice: Int) {
        let nombre = producto.value(forKey: "nombre") as? String ?? ""
        let stockDisponible = producto.value(forKey: "stock") as? Int32 ?? 0
        let cantidadActual = productosSeleccionados[indice].cantidad
        
        let alert = UIAlertController(
            title: "Cantidad - \(nombre)",
            message: "Stock disponible: \(stockDisponible)",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Cantidad"
            textField.keyboardType = .numberPad
            textField.text = cantidadActual > 0 ? "\(cantidadActual)" : ""
        }
        
        alert.addAction(UIAlertAction(title: "Confirmar", style: .default) { _ in
            guard let textField = alert.textFields?.first,
                  let cantidadTexto = textField.text,
                  let cantidad = Int(cantidadTexto),
                  cantidad >= 0 else {
                self.mostrarError("Por favor ingrese una cantidad válida")
                return
            }
            
            if cantidad > stockDisponible {
                self.mostrarError("Cantidad excede el stock disponible (\(stockDisponible))")
                return
            }
            
            self.productosSeleccionados[indice].cantidad = cantidad
            self.tableViewProductos.reloadRows(at: [IndexPath(row: indice, section: 0)], with: .none)
            self.actualizarTotal()
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }
    
    private func mostrarError(_ mensaje: String) {
        let alert = UIAlertController(title: "Error", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func mostrarExito(_ mensaje: String, completion: @escaping () -> Void) {
        let alert = UIAlertController(title: "✅ Éxito", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion()
        })
        present(alert, animated: true)
    }
    
    // ✅ NUEVO: Para mostrar advertencias (pedido creado pero no enviado a Firebase)
    private func mostrarAdvertencia(_ mensaje: String, completion: @escaping () -> Void) {
        let alert = UIAlertController(title: "⚠️ Advertencia", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Entendido", style: .default) { _ in
            completion()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension CrearPedidoViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return productos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CeldaProducto", for: indexPath)
        let producto = productos[indexPath.row]
        let cantidadSeleccionada = productosSeleccionados[indexPath.row].cantidad
        
        let nombre = producto.value(forKey: "nombre") as? String ?? ""
        let precio = producto.value(forKey: "precio") as? Double ?? 0.0
        let stock = producto.value(forKey: "stock") as? Int32 ?? 0
        
        var configuracion = cell.defaultContentConfiguration()
        configuracion.text = nombre
        configuracion.secondaryText = "S/. \(String(format: "%.2f", precio)) | Stock: \(stock)"
        
        if cantidadSeleccionada > 0 {
            configuracion.secondaryText! += " | Seleccionado: \(cantidadSeleccionada)"
            cell.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        } else {
            cell.backgroundColor = UIColor.systemBackground
        }
        
        // Mostrar estado de stock
        if stock <= 0 {
            configuracion.secondaryTextProperties.color = .systemRed
            configuracion.textProperties.color = .systemGray
        } else if stock <= (producto.value(forKey: "stockMinimo") as? Int32 ?? 0) {
            configuracion.secondaryTextProperties.color = .systemOrange
        }
        
        cell.contentConfiguration = configuracion
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension CrearPedidoViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let producto = productos[indexPath.row]
        let stock = producto.value(forKey: "stock") as? Int32 ?? 0
        
        if stock <= 0 {
            mostrarError("Producto sin stock disponible")
            return
        }
        
        mostrarSeleccionCantidad(paraProducto: producto, enIndice: indexPath.row)
    }
}

// MARK: - UIPickerViewDataSource
extension CrearPedidoViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return destinos.count
    }
}

// MARK: - UIPickerViewDelegate
extension CrearPedidoViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return destinos[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        destinoSeleccionado = destinos[row]
    }
}
