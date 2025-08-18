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
    
    // ACTUALIZADO: Crear pedido con NotificationCenter
    @IBAction func crearPedido(_ sender: UIButton) {
        guard validarDatos() else { return }
        
        let cliente = txtCliente.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Crear el pedido
        let pedido = coreDataManager.crearPedido(cliente: cliente, destino: destinoSeleccionado, total: totalPedido)
        
        // Agregar los productos al pedido
        for item in productosSeleccionados {
            if item.cantidad > 0 {
                coreDataManager.agregarDetallePedido(
                    pedido: pedido,
                    producto: item.producto,
                    cantidad: Int32(item.cantidad)
                )
            }
        }
        
        mostrarExito("✅ Pedido creado correctamente") {
            // NUEVO: Notificar actualización automática
            NotificationCenter.default.post(name: .pedidosActualizados, object: nil)
            NotificationCenter.default.post(name: .productosActualizados, object: nil) // También productos por stock
            
            self.dismiss(animated: true)
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
        
        let alert = UIAlertController(title: "Seleccionar Cantidad", message: "Producto: \(nombre)\nStock disponible: \(stockDisponible)", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Cantidad"
            textField.keyboardType = .numberPad
            textField.text = "\(cantidadActual)"
        }
        
        alert.addAction(UIAlertAction(title: "Confirmar", style: .default) { _ in
            if let textField = alert.textFields?.first,
               let texto = textField.text,
               let cantidad = Int(texto),
               cantidad >= 0,
               cantidad <= stockDisponible {
                self.productosSeleccionados[indice].cantidad = cantidad
                self.tableViewProductos.reloadRows(at: [IndexPath(row: indice, section: 0)], with: .none)
                self.actualizarTotal()
            } else {
                self.mostrarError("Cantidad inválida")
            }
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
        let alert = UIAlertController(title: "Éxito", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
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
        let nombre = producto.value(forKey: "nombre") as? String ?? ""
        let precio = producto.value(forKey: "precio") as? Double ?? 0.0
        let stock = producto.value(forKey: "stock") as? Int32 ?? 0
        let cantidadSeleccionada = productosSeleccionados[indexPath.row].cantidad
        
        cell.textLabel?.text = nombre
        cell.detailTextLabel?.text = "S/. \(String(format: "%.2f", precio)) • Stock: \(stock) • Cantidad: \(cantidadSeleccionada)"
        
        // Cambiar apariencia si está seleccionado
        if cantidadSeleccionada > 0 {
            cell.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            cell.accessoryType = .checkmark
        } else {
            cell.backgroundColor = .systemBackground
            cell.accessoryType = .none
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension CrearPedidoViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let producto = productos[indexPath.row]
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
